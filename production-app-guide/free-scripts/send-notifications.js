/**
 * Free push-notification sender (no Blaze/billing needed).
 * Runs every few minutes via GitHub Actions. Does two jobs:
 *
 * 1) Student notifications: checks Firestore for any notification the admin
 *    sent that hasn't been pushed yet, sends it to the "all_students" topic,
 *    then marks it "sent" so it's never sent twice.
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
 * Delivery happens within the polling interval (about 5-10 minutes)
 * instead of truly real-time - a fair trade-off for zero cost and no
 * credit card.
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
// Only queries from the last 2 days are announced, so old unanswered queries
// never trigger a confusing alert.
const QUERY_WINDOW_MS = 48 * 60 * 60 * 1000;
// Same idea for grant requests (7 days), so an old forgotten request can
// never trigger a confusing alert.
const REQUEST_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

async function sendStudentNotifications() {
  const snap = await db.collection("notifications").where("sent", "==", false).get();
  if (snap.empty) {
    console.log("No pending notifications.");
    return;
  }

  for (const doc of snap.docs) {
    const data = doc.data();
    if ((data.failedAttempts || 0) >= MAX_ATTEMPTS) {
      console.log(`Skipping "${data.title}" - failed ${data.failedAttempts} times already.`);
      continue;
    }
    try {
      await admin.messaging().send({
        topic: "all_students",
        notification: { title: String(data.title || ""), body: String(data.body || "") },
        android: { priority: "high" },
      });
      await doc.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log(`Sent: ${data.title}`);
    } catch (err) {
      console.error(`Failed to send "${data.title}":`, err.message);
      try {
        await doc.ref.update({
          failedAttempts: admin.firestore.FieldValue.increment(1),
          lastError: String(err.message || err).slice(0, 200),
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
  const snap = await db.collection("queries").where("status", "==", "open").get();
  const cutoff = Date.now() - QUERY_WINDOW_MS;
  const fresh = snap.docs
    .filter((d) => d.data().adminNotified !== true && millisOf(d.data().createdAt) >= cutoff)
    .sort((a, b) => millisOf(b.data().createdAt) - millisOf(a.data().createdAt))
    .slice(0, 400);
  if (fresh.length === 0) {
    console.log("No new queries for the admin.");
    return;
  }

  const latest = fresh[0].data();
  const who = String(latest.studentName || "Student").trim() || "Student";
  const text = String(latest.text || "").replace(/\s+/g, " ").trim().slice(0, 90);
  const title = fresh.length === 1 ? "Nayi query aayi hai" : `${fresh.length} nayi queries aayi hain`;

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
  // Single-field filter only (no composite index needed); the rest is
  // filtered here.
  const snap = await db.collection("accessRequests").where("status", "==", "pending").get();
  const cutoff = Date.now() - REQUEST_WINDOW_MS;
  const fresh = snap.docs
    .filter((d) => d.data().adminNotified !== true && millisOf(d.data().requestedAt) >= cutoff)
    .sort((a, b) => millisOf(b.data().requestedAt) - millisOf(a.data().requestedAt))
    .slice(0, 400);
  if (fresh.length === 0) {
    console.log("No new grant requests for the admin.");
    return;
  }

  const latest = fresh[0].data();
  const who = String(latest.studentName || latest.studentEmail || "Student").trim() || "Student";
  const batchName = String(latest.batchTitle || "").replace(/\s+/g, " ").trim().slice(0, 60);
  const title = fresh.length === 1 ? "Nayi Grant Request aayi hai" : `${fresh.length} nayi Grant Requests aayi hain`;
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
