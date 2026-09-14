/**
 * Free push-notification sender (no Blaze/billing needed).
 * Runs every few minutes via GitHub Actions. Checks Firestore for any
 * notification the admin sent that hasn't been pushed yet, sends it via
 * FCM, then marks it "sent" so it's never sent twice.
 *
 * This gives near-instant delivery (within the polling interval, e.g.
 * every 3-5 minutes) instead of truly real-time — a fair trade-off for
 * zero cost and no credit card.
 */
const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

(async () => {
  const snap = await db.collection("notifications").where("sent", "==", false).get();
  if (snap.empty) {
    console.log("No pending notifications.");
    process.exit(0);
  }

  for (const doc of snap.docs) {
    const data = doc.data();
    try {
      await admin.messaging().send({
        topic: "all_students",
        notification: { title: data.title, body: data.body },
      });
      await doc.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log(`Sent: ${data.title}`);
    } catch (err) {
      console.error(`Failed to send "${data.title}":`, err.message);
    }
  }
  process.exit(0);
})();
