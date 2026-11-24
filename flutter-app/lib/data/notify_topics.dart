// =============================================================================
//  Notification topics (FCM) - student apni pasand ke exam ke alerts chun sakta hai.
//
//  Har exam ka ek FCM topic hota hai (naam sirf a-z, 0-9, _ ho). Admin Panel >
//  Notify me "Send to" chunkar kisi ek exam ko alert bhej sakta hai; GitHub
//  automation (send-notifications.js) use usi topic par bhejta hai.
//
//  Naya exam jodna ho: neeche kExamTopics me ek NotifyTopic jodo
//  (id hamesha 'exam_' se shuru ho, warna script use bhejega nahi).
// =============================================================================

class NotifyTopic {
  final String id; // FCM topic ka naam
  final String emoji;
  final String en;
  final String hi;
  const NotifyTopic(this.id, this.emoji, this.en, this.hi);
}

/// Roz shaam ka study reminder (GitHub automation bhejta hai) - student chahe to band kar sakta hai.
const String kDailyReminderTopic = 'daily_reminder';

const List<NotifyTopic> kExamTopics = [
  // NOTE: id (FCM topic) kabhi mat badlo - purane students ki choice aur subscription isi id se hai. Sirf naam badal sakte hain.
  NotifyTopic('exam_bank_po', '🏦', 'Banking/Insurance PO/Clerk', 'बैंकिंग/इंश्योरेंस पीओ/क्लर्क'),
  NotifyTopic('exam_uppsc', '🏛️', 'UPPCS', 'यूपीपीसीएस'),
  NotifyTopic('exam_upsssc', '📋', 'UPSSSC', 'यूपीएसएसएससी'),
  NotifyTopic('exam_ahc_ro', '⚖️', 'AHC RO/ARO/GroupC', 'एएचसी आरओ/एआरओ/ग्रुप सी'),
  NotifyTopic('exam_rrb_ntpc', '🚆', 'RRB NTPC/Station Master', 'आरआरबी एनटीपीसी/स्टेशन मास्टर'),
  NotifyTopic('exam_ssc_cgl', '🧾', 'SSC CGL/CHSL', 'एसएससी सीजीएल/सीएचएसएल'),
];

/// Notification kis exam ke liye hai (list me chhota tag dikhane ke liye). Sabke liye ho to null.
String? examLabelForTopic(String topic) {
  for (final t in kExamTopics) {
    if (t.id == topic) return t.en;
  }
  return null;
}
