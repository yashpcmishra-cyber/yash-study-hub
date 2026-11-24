// Keeps only the LATEST 10 mock-test attempts (collection "mockTestAttempts", shown in the
// Admin Panel -> Attempts tab) and deletes all older ones, so Firestore storage stays tiny and the
// Attempts tab reads at most 10 documents. Same firebase-admin + FIREBASE_SERVICE_ACCOUNT
// pattern as cleanup-queries.js / cleanup-notifications.js.
// (Student ranks live in a different collection, "mockScores", and are NOT touched.)
const admin = require('firebase-admin');

const KEEP_LATEST = 10;

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteOldAttempts() {
  // Newest first, skip the 10 newest, everything after them is deleted.
  // select() = only the document references are returned (no field data).
  const snapshot = await db
    .collection('mockTestAttempts')
    .orderBy('submittedAt', 'desc')
    .offset(KEEP_LATEST)
    .select()
    .get();

  if (snapshot.empty) {
    console.log('Only ' + KEEP_LATEST + ' or fewer attempts exist. Nothing to delete.');
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

  console.log('Deleted ' + deleted + ' old attempt(s). Kept the latest ' + KEEP_LATEST + '.');
}

deleteOldAttempts().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
