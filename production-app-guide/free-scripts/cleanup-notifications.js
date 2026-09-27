// Deletes notification documents older than RETENTION_DAYS from Firestore.
// This is the ONLY step that actually frees up Firestore storage - what the
// app shows on screen is controlled separately (in firestore_service.dart)
// and does not delete anything.
//
// Uses the exact same firebase-admin + FIREBASE_SERVICE_ACCOUNT pattern as
// send-notifications.js, so it works with the secret you already have set up.
const admin = require('firebase-admin');

const RETENTION_DAYS = 30;

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteOldNotifications() {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000)
  );

  const snapshot = await db
    .collection('notifications')
    .where('sentAt', '<', cutoff)
    .get();

  if (snapshot.empty) {
    console.log('No notifications older than ' + RETENTION_DAYS + ' days. Nothing to delete.');
    return;
  }

  // Firestore only allows 500 writes per batch, so delete in chunks.
  const docs = snapshot.docs;
  let deleted = 0;
  for (let i = 0; i < docs.length; i += 500) {
    const chunk = docs.slice(i, i + 500);
    const batch = db.batch();
    chunk.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += chunk.length;
  }

  console.log('Deleted ' + deleted + ' notification(s) older than ' + RETENTION_DAYS + ' days.');
}

deleteOldNotifications().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
