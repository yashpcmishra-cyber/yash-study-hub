/**
 * Free push-notification sender (no Blaze/billing needed).
 * Runs every few minutes via GitHub Actions. Checks Firestore for any
 * notification the admin sent that hasn't been pushed yet, sends it via
 * FCM, then marks it "sent" so it's never sent twice.
 *
 * Delivery happens within the polling interval (about 5-10 minutes)
 * instead of truly real-time — a fair trade-off for zero cost and no
 * credit card.
 *
 * A notification that keeps failing (for example an empty title) is tried
 * at most 5 times and then left alone, so it can never block the others.
 */
const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const MAX_ATTEMPTS = 5;

(async () => {
  const snap = await db.collection("notifications").where("sent", "==", false).get();
  if (snap.empty) {
    console.log("No pending notifications.");
    process.exit(0);
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
  process.exit(0);
})();
