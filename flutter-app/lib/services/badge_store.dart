import 'package:shared_preferences/shared_preferences.dart';
import '../data/flashcard_data.dart';
import 'flashcard_store.dart';
import 'revision_store.dart';
import 'speed_math_store.dart';
import 'study_store.dart';
import 'study_time_store.dart';
import 'syllabus_store.dart';

// =============================================================================
//  BadgeStore - Achievements. Sab kuch phone ke data se nikalta hai
//  (streak, sawal, tests, study time, revision, flashcards). Firestore = 0.
// =============================================================================

class BadgeInfo {
  final String id;
  final String emoji;
  final String title;
  final String titleHi;
  final String desc;
  final String descHi;
  final int current;
  final int target;
  const BadgeInfo({
    required this.id,
    required this.emoji,
    required this.title,
    required this.titleHi,
    required this.desc,
    required this.descHi,
    required this.current,
    required this.target,
  });

  bool get unlocked => current >= target;
  double get ratio => target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0).toDouble();
}

class BadgeStore {
  BadgeStore._();

  static const _kSeen = 'ysh3_badges_seen';

  static Future<List<BadgeInfo>> evaluate() async {
    final life = await StudyStore.lifetime();
    final focusSec = await StudyTimeStore.totalSeconds();
    final mastered = await RevisionStore.masteredCount();
    final cards = await FlashcardStore.knownCount();
    final speedRounds = await SpeedMathStore.totalRounds();
    final sylDone = await SyllabusStore.totalDone();
    final focusMin = focusSec ~/ 60;
    return [
      BadgeInfo(id: 'first', emoji: '🌱', title: 'First Step', titleHi: 'पहला कदम', desc: 'Finish your first test or quiz', descHi: 'पहला टेस्ट या क्विज़ पूरा करें', current: life.tests, target: 1),
      BadgeInfo(id: 'streak3', emoji: '🔥', title: '3-Day Streak', titleHi: '3 दिन की स्ट्रीक', desc: 'Open the app 3 days in a row', descHi: 'लगातार 3 दिन ऐप खोलें', current: life.maxStreak, target: 3),
      BadgeInfo(id: 'streak7', emoji: '⚡', title: '7-Day Streak', titleHi: '7 दिन की स्ट्रीक', desc: 'Open the app 7 days in a row', descHi: 'लगातार 7 दिन ऐप खोलें', current: life.maxStreak, target: 7),
      BadgeInfo(id: 'streak30', emoji: '👑', title: '30-Day Streak', titleHi: '30 दिन की स्ट्रीक', desc: 'Open the app 30 days in a row', descHi: 'लगातार 30 दिन ऐप खोलें', current: life.maxStreak, target: 30),
      BadgeInfo(id: 'q100', emoji: '🎯', title: '100 Questions', titleHi: '100 सवाल', desc: 'Answer 100 questions', descHi: '100 सवाल हल करें', current: life.questions, target: 100),
      BadgeInfo(id: 'q500', emoji: '🚀', title: '500 Questions', titleHi: '500 सवाल', desc: 'Answer 500 questions', descHi: '500 सवाल हल करें', current: life.questions, target: 500),
      BadgeInfo(id: 'q1000', emoji: '🏆', title: '1000 Questions', titleHi: '1000 सवाल', desc: 'Answer 1000 questions', descHi: '1000 सवाल हल करें', current: life.questions, target: 1000),
      BadgeInfo(id: 'high80', emoji: '🏅', title: 'Top Scorer', titleHi: 'टॉप स्कोरर', desc: 'Score 80% or more in a test', descHi: 'किसी टेस्ट में 80% या ज़्यादा लाएँ', current: life.highScores, target: 1),
      BadgeInfo(id: 'perfect', emoji: '💯', title: 'Perfect Score', titleHi: 'परफेक्ट स्कोर', desc: 'Score 100% in a test', descHi: 'किसी टेस्ट में 100% लाएँ', current: life.perfectScores, target: 1),
      BadgeInfo(id: 'focus1h', emoji: '⏱️', title: 'Focus Starter', titleHi: 'फोकस शुरुआत', desc: 'Study 1 hour with the Study Timer (minutes)', descHi: 'स्टडी टाइमर से 1 घंटा पढ़ें (मिनट)', current: focusMin, target: 60),
      BadgeInfo(id: 'focus10h', emoji: '🧘', title: 'Deep Focus', titleHi: 'डीप फोकस', desc: 'Study 10 hours with the Study Timer (minutes)', descHi: 'स्टडी टाइमर से 10 घंटे पढ़ें (मिनट)', current: focusMin, target: 600),
      BadgeInfo(id: 'rev10', emoji: '🔁', title: 'Revision Hero', titleHi: 'रिवीज़न हीरो', desc: 'Master 10 mistakes with Smart Revision', descHi: 'Smart Revision से 10 गलतियाँ पक्की करें', current: mastered, target: 10),
      BadgeInfo(id: 'cards20', emoji: '🃏', title: 'Flashcard Starter', titleHi: 'फ्लैशकार्ड शुरुआत', desc: 'Learn 20 flashcards', descHi: '20 फ्लैशकार्ड याद करें', current: cards, target: 20),
      BadgeInfo(id: 'cards60', emoji: '🧠', title: 'Flashcard Pro', titleHi: 'फ्लैशकार्ड प्रो', desc: 'Learn 60 flashcards', descHi: '60 फ्लैशकार्ड याद करें', current: cards > kFlashcards.length ? kFlashcards.length : cards, target: 60),
      BadgeInfo(id: 'speed5', emoji: '⚡', title: 'Speed Starter', titleHi: 'स्पीड स्टार्टर', desc: 'Play 5 rounds in Speed Maths Arena', descHi: 'स्पीड मैथ्स अरेना के 5 राउंड खेलें', current: speedRounds, target: 5),
      BadgeInfo(id: 'speed30', emoji: '🧮', title: 'Human Calculator', titleHi: 'ह्यूमन कैलकुलेटर', desc: 'Play 30 rounds in Speed Maths Arena', descHi: 'स्पीड मैथ्स अरेना के 30 राउंड खेलें', current: speedRounds, target: 30),
      BadgeInfo(id: 'syl10', emoji: '📚', title: 'Syllabus Starter', titleHi: 'सिलेबस शुरुआत', desc: 'Complete 10 topics in Syllabus Tracker', descHi: 'सिलेबस ट्रैकर में 10 टॉपिक पूरे करें', current: sylDone, target: 10),
      BadgeInfo(id: 'syl50', emoji: '🎓', title: 'Syllabus Master', titleHi: 'सिलेबस मास्टर', desc: 'Complete 50 topics in Syllabus Tracker', descHi: 'सिलेबस ट्रैकर में 50 टॉपिक पूरे करें', current: sylDone, target: 50),
    ];
  }

  /// "Level" ka naam - kitne badge khule hain us hisaab se.
  static String level(int unlocked) {
    if (unlocked >= 16) return 'Legend / लीजेंड';
    if (unlocked >= 11) return 'Champion / चैंपियन';
    if (unlocked >= 6) return 'Achiever / विजेता';
    if (unlocked >= 2) return 'Learner / जिज्ञासु';
    return 'Beginner / शुरुआती';
  }

  static Future<Set<String>> seenIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_kSeen) ?? const <String>[]).toSet();
  }

  /// Student ne jo badge dekh liye unhe "seen" mark karo.
  static Future<void> markSeen(List<BadgeInfo> all) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSeen, all.where((b) => b.unlocked).map((b) => b.id).toList());
  }

  /// Kitne badge khule hain par abhi tak dekhe nahi gaye.
  static Future<int> newCount(List<BadgeInfo> all) async {
    final seen = await seenIds();
    return all.where((b) => b.unlocked && !seen.contains(b.id)).length;
  }
}
