/**
 * Free daily study reminder (no Blaze/billing needed).
 * Runs once a day via GitHub Actions (about 7 PM India time) and sends ONE
 * short push to the "daily_reminder" topic. Only students who switched
 * "Daily study reminder" ON in the app (Notifications > settings icon) are
 * subscribed to this topic, so everyone else is never disturbed.
 *
 * The message changes with the day of the week, so it never feels repeated.
 * To change the wording, edit the MESSAGES list below (index 0 = Sunday).
 */
const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const MESSAGES = [
  { title: "Sunday revision / संडे रिवीजन", body: "Revise this week's topics and take one Mock Test. / इस हफ्ते के टॉपिक दोहराएँ और एक मॉक टेस्ट दें।" },
  { title: "Daily Quiz time / डेली क्विज़ का समय", body: "Finish today's Daily Quiz in just 5 minutes. / आज का डेली क्विज़ सिर्फ 5 मिनट में पूरा करें।" },
  { title: "Current Affairs / करेंट अफेयर्स", body: "Read today's Current Affairs and keep your streak alive. / आज के करेंट अफेयर्स पढ़ें और स्ट्रीक बनाए रखें।" },
  { title: "Revision due / रिवीजन का समय", body: "Revise your wrong questions today. / आज अपने गलत सवालों का रिवीजन करें।" },
  { title: "Word of the Day / आज का शब्द", body: "Learn today's word with its synonyms and antonyms. / आज का शब्द उसके समानार्थी और विलोम के साथ सीखें।" },
  { title: "Mock Test time / मॉक टेस्ट का समय", body: "Attempt a Mock Test and check your rank. / एक मॉक टेस्ट दें और अपनी रैंक देखें।" },
  { title: "Weekly check / साप्ताहिक जाँच", body: "See your weekly report and plan the next week. / अपनी साप्ताहिक रिपोर्ट देखें और अगले हफ्ते की योजना बनाएँ।" },
];

(async () => {
  try {
    // India time (UTC+5:30), so "today" matches the student's day.
    const ist = new Date(Date.now() + 5.5 * 60 * 60 * 1000);
    const m = MESSAGES[ist.getUTCDay()];
    await admin.messaging().send({
      topic: "daily_reminder",
      notification: { title: m.title, body: m.body },
      android: { priority: "normal" },
    });
    console.log(`Daily reminder sent: ${m.title}`);
  } catch (err) {
    console.error("Daily reminder failed:", err.message);
    process.exit(1);
  }
  process.exit(0);
})();
