// Leaderboard / rank data ko 30 din baad Firestore se hata deta hai.
//
// Leaderboard "mockScores/{testId}/scores/{uid}" se banta hai (har document me
// sirf score, timeSec, at - naam / email nahi). Ye script 30 din se purane
// score documents delete karta hai, taaki Firestore storage badhta na rahe.
// Isse rank list "pichhle 30 din" ki ban jaati hai.
//
// Koi composite index ya console setting nahi chahiye: pehle har test ka folder
// (listDocuments), phir uske andar sirf ek field ("at") par query.
// Same firebase-admin + FIREBASE_SERVICE_ACCOUNT pattern as cleanup-attempts.js.
const admin = require('firebase-admin');

const RETENTION_DAYS = 30;

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteOldScores() {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000)
  );

  // listDocuments() un test-folders ko bhi deta hai jinka khud ka document nahi hai
  // (sirf "scores" subcollection hai) - aur ye reads gine nahi jaate.
  const testRefs = await db.collection('mockScores').listDocuments();
  let deleted = 0;

  for (const testRef of testRefs) {
    // Ek test ke 500+ purane scores ho sakte hain: baar-baar chunk me hatao.
    for (;;) {
      const snap = await testRef.collection('scores').where('at', '<', cutoff).limit(400).get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      deleted += snap.size;
      if (snap.size < 400) break;
    }
  }

  if (deleted === 0) {
    console.log('No scores older than ' + RETENTION_DAYS + ' days. Nothing to delete.');
  } else {
    console.log('Deleted ' + deleted + ' score(s) older than ' + RETENTION_DAYS + ' days.');
  }
}

deleteOldScores().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
