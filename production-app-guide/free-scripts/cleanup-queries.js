// Deletes student "Queries" (doubts + admin replies) older than RETENTION_DAYS
// from Firestore, so storage does not keep growing. Same firebase-admin +
// FIREBASE_SERVICE_ACCOUNT pattern as cleanup-notifications.js.
// (The app also hides doubts older than this on its own.)
const admin = require('firebase-admin');

const RETENTION_DAYS = 20; // keep in sync with kQueryRetentionDays in the app

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteOldQueries() {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000)
  );

  const snapshot = await db
    .collection('queries')
    .where('createdAt', '<', cutoff)
    .get();

  if (snapshot.empty) {
    console.log('No queries older than ' + RETENTION_DAYS + ' days. Nothing to delete.');
    return;
  }

  // Firestore allows 500 writes per batch, so delete in chunks.
  const docs = snapshot.docs;
  let deleted = 0;
  for (let i = 0; i < docs.length; i += 500) {
    const chunk = docs.slice(i, i + 500);
    const batch = db.batch();
    chunk.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += chunk.length;
  }

  console.log('Deleted ' + deleted + ' query(ies) older than ' + RETENTION_DAYS + ' days.');
}

deleteOldQueries().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
