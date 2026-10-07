// Deletes mock-test attempts (collection "mockTestAttempts", shown in the
// Admin Panel -> Attempts tab) older than RETENTION_DAYS, so Firestore storage
// does not keep growing. Same firebase-admin + FIREBASE_SERVICE_ACCOUNT
// pattern as cleanup-queries.js / cleanup-notifications.js.
// (Student ranks live in a different collection, "mockScores", and are NOT touched.)
const admin = require('firebase-admin');

const RETENTION_DAYS = 30;

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteOldAttempts() {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000)
  );

  const snapshot = await db
    .collection('mockTestAttempts')
    .where('submittedAt', '<', cutoff)
    .get();

  if (snapshot.empty) {
    console.log('No attempts older than ' + RETENTION_DAYS + ' days. Nothing to delete.');
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

  console.log('Deleted ' + deleted + ' attempt(s) older than ' + RETENTION_DAYS + ' days.');
}

deleteOldAttempts().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
