/**
 * Free push-notification sender (no Blaze/billing needed).
 * Runs once an HOUR via GitHub Actions (to keep Firestore reads low; for an
 * urgent push run it by hand: GitHub > Actions > Send Notifications > Run
 * workflow). Does three jobs:
 *
 * 1) Student notifications: checks Firestore for any notification the admin
 *    sent that hasn't been pushed yet, sends it to the "all_students" topic
 *    (or to one "exam_..." topic when the admin picked a single exam), then
 *    marks it "sent" so it's never sent twice.
 * 2) Admin alert: when a student sends a new query (a doubt), sends ONE push
 *    to the "admin_alerts" topic (only the admin's phone is subscribed, from
 *    Admin Panel) and marks those queries "adminNotified" so they are never
 *    announced twice.
 * 3) Admin alert for paid-batch grant requests: when a student sends a new
 *    access request (Check Access), sends ONE push to the same
 *    "admin_alerts" topic and marks those requests "adminNotified" so they
 *    are never announced twice. A student who re-sends a request replaces
 *    the request document, so that one is announced again.
 *
 * Delivery happens within the polling interval (up to about an hour)
 * instead of truly real-time - a fair trade-off for zero cost and no
 * credit card.
 *
 * FEWER READS: every query below reads ONLY what is needed. The two admin
 * alerts look only at doubts / requests created inside the last
 * *_WINDOW_MS (older ones were already announced or are no longer news), and
 * a notification that failed MAX_ATTEMPTS times is marked sent:"failed" once,
 * so it is never read again.
 *
 * A notification that keeps failing (for example an empty title) is tried
 * at most 5 times and then left alone, so it can never block the others.
 * The three jobs are independent: if one fails, the others still run.
 */
const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const MAX_ATTEMPTS = 5;
// How far back the admin alerts look. Must be longer than the schedule gap (1 hour)
// so a late or skipped run still finds everything. Docs inside the window that were
// already announced carry adminNotified:true, so nothing is announced twice.
const QUERY_WINDOW_MS = 6 * 60 * 60 * 1000;
const REQUEST_WINDOW_MS = 6 * 60 * 60 * 1000;
// The admin can send a notification to ONE exam only. The app saves that choice
// in the notification's "topic" field (for example "exam_bank_po"). Students
// subscribe to these topics in the app (signup / Profile / Notifications >
// settings). An empty or missing "topic" (all old notifications) means EVERY
// student, through the "all_students" topic.
function topicFor(data) {
  const topic = String(data.topic || "").trim();
  if (topic === "") return "all_students";
  if (/^exam_[a-z0-9_]+$/.test(topic)) return topic;
  throw new Error(`Unknown topic "${topic}"`);
}

async function sendStudentNotifications() {
  const snap = await db.collection("notifications").where("sent", "==", false).get();
  if (snap.empty) {
    console.log("No pending notifications.");
    return;
  }

  for (const doc of snap.docs) {
    const data = doc.data();
    if ((data.failedAttempts || 0) >= MAX_ATTEMPTS) {
      console.log(`Giving up on "${data.title}" - failed ${data.failedAttempts} times. Marked sent:"failed" so it is not read again.`);
      try {
        await doc.ref.update({ sent: "failed" });
      } catch (e) {
        // ignore
      }
      continue;
    }
    try {
      await admin.messaging().send({
        topic: topicFor(data),
        notification: { title: String(data.title || ""), body: String(data.body || "") },
        android: { priority: "high" },
      });
      await doc.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log(`Sent (${topicFor(data)}): ${data.title}`);
    } catch (err) {
      console.error(`Failed to send "${data.title}":`, err.message);
      try {
        const attempts = (data.failedAttempts || 0) + 1;
        await doc.ref.update({
          failedAttempts: admin.firestore.FieldValue.increment(1),
          lastError: String(err.message || err).slice(0, 200),
          // Out of attempts: leave the sent==false query for good (never read again).
          ...(attempts >= MAX_ATTEMPTS ? { sent: "failed" } : {}),
        });
      } catch (e) {
        // ignore
      }
    }
  }
}

function millisOf(ts) {
  return ts && typeof ts.toMillis === "function" ? ts.toMillis() : 0;
}

async function sendAdminQueryAlert() {
  const cutoff = Date.now() - QUERY_WINDOW_MS;
  // Single-field range query (no composite index needed): reads only the doubts
  // created inside the window instead of every open doubt on every run.
  const snap = await db.collection("queries").where("createdAt", ">=", admin.firestore.Timestamp.fromMillis(cutoff)).get();
  const fresh = snap.docs
    .filter((d) => d.data().status === "open" && d.data().adminNotified !== true && millisOf(d.data().createdAt) >= cutoff)
    .sort((a, b) => millisOf(b.data().createdAt) - millisOf(a.data().createdAt))
    .slice(0, 400);
  if (fresh.length === 0) {
    console.log("No new queries for the admin.");
    return;
  }

  const latest = fresh[0].data();
  const who = String(latest.studentName || "Student").trim() || "Student";
  const text = String(latest.text || "").replace(/\s+/g, " ").trim().slice(0, 90);
  const title = fresh.length === 1 ? "New doubt received / नया डाउट आया है" : `${fresh.length} new doubts received / ${fresh.length} नए डाउट आए हैं`;

  await admin.messaging().send({
    topic: "admin_alerts",
    notification: { title, body: `${who}: ${text}` },
    data: { type: "admin_query" },
    android: { priority: "high" },
  });

  const batch = db.batch();
  for (const d of fresh) {
    batch.update(d.ref, { adminNotified: true });
  }
  await batch.commit();
  console.log(`Admin alerted about ${fresh.length} new query(ies).`);
}

async function sendAdminGrantAlert() {
  // Single-field range query (no composite index needed): reads only the requests
  // made inside the window; the rest is filtered here.
  const cutoff = Date.now() - REQUEST_WINDOW_MS;
  const snap = await db.collection("accessRequests").where("requestedAt", ">=", admin.firestore.Timestamp.fromMillis(cutoff)).get();
  const fresh = snap.docs
    .filter((d) => d.data().status === "pending" && d.data().adminNotified !== true && millisOf(d.data().requestedAt) >= cutoff)
    .sort((a, b) => millisOf(b.data().requestedAt) - millisOf(a.data().requestedAt))
    .slice(0, 400);
  if (fresh.length === 0) {
    console.log("No new grant requests for the admin.");
    return;
  }

  const latest = fresh[0].data();
  const who = String(latest.studentName || latest.studentEmail || "Student").trim() || "Student";
  const batchName = String(latest.batchTitle || "").replace(/\s+/g, " ").trim().slice(0, 60);
  const title = fresh.length === 1 ? "New Grant Request / नई ग्रांट रिक्वेस्ट आई है" : `${fresh.length} new Grant Requests / ${fresh.length} नई ग्रांट रिक्वेस्ट आई हैं`;
  const body = batchName ? `${who}: ${batchName}` : who;

  await admin.messaging().send({
    topic: "admin_alerts",
    notification: { title, body },
    data: { type: "admin_grant" },
    android: { priority: "high" },
  });

  const batch = db.batch();
  for (const d of fresh) {
    batch.update(d.ref, { adminNotified: true });
  }
  await batch.commit();
  console.log(`Admin alerted about ${fresh.length} new grant request(s).`);
}

(async () => {
  try {
    await sendStudentNotifications();
  } catch (err) {
    console.error("Student notifications job failed:", err.message);
  }
  try {
    await sendAdminQueryAlert();
  } catch (err) {
    console.error("Admin query alert job failed:", err.message);
  }
  try {
    await sendAdminGrantAlert();
  } catch (err) {
    console.error("Admin grant alert job failed:", err.message);
  }
  process.exit(0);
})();
