import 'activity_log.dart';
import 'speed_math_store.dart';
import 'study_store.dart';
import 'study_time_store.dart';
import 'syllabus_store.dart';

// =============================================================================
//  WeeklyReportService - pichhle 7 din ka report card, phone ke data se.
//  (study timer, sawal, tests, syllabus topics, speed maths, streak)
//  Kuch bhi alag save nahi hota aur Firestore ko 0 reads / 0 writes.
// =============================================================================

class WeekTip {
  final String en;
  final String hi;
  const WeekTip(this.en, this.hi);
}

class WeeklyReport {
  final List<DateTime> dates; // purana -> aaj (7)
  final List<int> questionsPerDay;
  final List<int> focusSecPerDay;
  final List<bool> active;
  final int questions;
  final int prevQuestions;
  final int focusSec;
  final int prevFocusSec;
  final int tests; // tests + daily quiz
  final double avgScore; // -1 = is hafte koi test nahi
  final double accuracy; // -1 = koi test nahi
  final String? strongSubject;
  final String? weakSubject;
  final int topics;
  final int speedRounds;
  final int speedCorrect;
  final int streak;
  final int score; // 0..100
  final String emoji;
  final String title;
  final String titleHi;
  final List<WeekTip> tips;

  const WeeklyReport({
    required this.dates,
    required this.questionsPerDay,
    required this.focusSecPerDay,
    required this.active,
    required this.questions,
    required this.prevQuestions,
    required this.focusSec,
    required this.prevFocusSec,
    required this.tests,
    required this.avgScore,
    required this.accuracy,
    required this.strongSubject,
    required this.weakSubject,
    required this.topics,
    required this.speedRounds,
    required this.speedCorrect,
    required this.streak,
    required this.score,
    required this.emoji,
    required this.title,
    required this.titleHi,
    required this.tips,
  });

  int get activeDays => active.where((a) => a).length;

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get rangeLabel {
    String f(DateTime d) => '${d.day} ${_months[d.month - 1]}';
    return '${f(dates.first)} – ${f(dates.last)}';
  }

  /// WhatsApp / Telegram par bhejne wala text.
  String shareText(String studyFmt) {
    final testLine = tests == 0 ? '📝 Tests & quizzes: 0' : '📝 Tests & quizzes: $tests (avg ${avgScore.round()}%)';
    return '📅 $rangeLabel\n'
        '⭐ Weekly score: $score/100 ($title)\n'
        '✅ Active days: $activeDays/7\n'
        '⏱️ Study time: $studyFmt\n'
        '🎯 Questions: $questions\n'
        '$testLine\n'
        '📚 Syllabus topics done: $topics\n'
        '⚡ Speed Maths rounds: $speedRounds\n'
        '🔥 Streak: $streak days';
  }
}

class _Sub {
  int correct = 0;
  int attempted = 0;
  double get accuracy => attempted == 0 ? 0 : correct / attempted * 100;
}

class WeeklyReportService {
  WeeklyReportService._();

  static const int _weeklyFocusTargetSec = 7 * 3600; // roz 1 ghanta

  static Future<WeeklyReport> build() async {
    final newestFirst = ActivityLog.lastDays(7);
    final days = newestFirst.reversed.toList(); // purana -> aaj
    final prevDays = ActivityLog.lastDays(7, skip: 7);

    final now = DateTime.now();
    final dates = List<DateTime>.generate(7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));

    // sawal
    final qMap = await ActivityLog.questionsFor(days);
    final prevQMap = await ActivityLog.questionsFor(prevDays);
    final qPerDay = days.map((d) => qMap[d] ?? 0).toList();
    final questions = qPerDay.fold<int>(0, (a, b) => a + b);
    final prevQuestions = prevQMap.values.fold<int>(0, (a, b) => a + b);

    // padhai ka time
    final focusPerDay = <int>[];
    for (final d in days) {
      focusPerDay.add(await StudyTimeStore.secondsOn(d));
    }
    var prevFocus = 0;
    for (final d in prevDays) {
      prevFocus += await StudyTimeStore.secondsOn(d);
    }
    final focusSec = focusPerDay.fold<int>(0, (a, b) => a + b);

    // tests / quiz
    final start = dates.first;
    final history = (await StudyStore.history()).where((r) => !r.at.isBefore(start)).toList();
    var tests = 0;
    var pctSum = 0.0;
    var correct = 0;
    var attempted = 0;
    final bySubject = <String, _Sub>{};
    final testDays = <String>{};
    for (final r in history) {
      testDays.add(ActivityLog.keyOf(r.at));
      if (r.attempted == 0) continue;
      tests++;
      pctSum += r.scorePercent;
      correct += r.correct;
      attempted += r.attempted;
      final name = r.subject.trim();
      if (name.isEmpty || name == 'Daily Quiz') continue;
      final s = bySubject.putIfAbsent(name, () => _Sub());
      s.correct += r.correct;
      s.attempted += r.attempted;
    }
    final avgScore = tests == 0 ? -1.0 : pctSum / tests;
    final accuracy = attempted == 0 ? -1.0 : correct / attempted * 100;

    String? strong;
    String? weak;
    final ranked = bySubject.entries.where((e) => e.value.attempted >= 10).toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    if (ranked.length >= 2 && ranked.first.value.accuracy < ranked.last.value.accuracy) {
      weak = ranked.first.key;
      strong = ranked.last.key;
    }

    // syllabus aur speed maths
    final doneMap = await SyllabusStore.doneMap();
    final topicDays = <String>{...doneMap.values.where(days.contains)};
    final topics = doneMap.values.where(days.contains).length;
    final speedTotals = await SpeedMathStore.sumDays(days);
    final speedDayRounds = <String>{};
    for (final d in days) {
      final one = await SpeedMathStore.sumDays([d]);
      if (one[0] > 0) speedDayRounds.add(d);
    }

    // kaun-se din active the
    final active = <bool>[];
    for (var i = 0; i < 7; i++) {
      final d = days[i];
      active.add(qPerDay[i] > 0 || focusPerDay[i] > 0 || testDays.contains(d) || topicDays.contains(d) || speedDayRounds.contains(d));
    }
    final activeDays = active.where((a) => a).length;

    final streak = (await StudyStore.readStreak()).days;
    final goal = await StudyStore.goalTarget();

    // weekly score (0..100)
    final focusPart = (focusSec / _weeklyFocusTargetSec).clamp(0.0, 1.0).toDouble();
    final qTarget = 7 * goal;
    final qPart = qTarget <= 0 ? 0.0 : (questions / qTarget).clamp(0.0, 1.0).toDouble();
    final testPart = (tests / 2).clamp(0.0, 1.0).toDouble();
    final score = (activeDays / 7 * 40 + focusPart * 25 + qPart * 25 + testPart * 10).round().clamp(0, 100).toInt();

    String emoji;
    String title;
    String titleHi;
    if (score >= 85) {
      emoji = '🏆';
      title = 'Topper';
      titleHi = 'टॉपर';
    } else if (score >= 65) {
      emoji = '⭐';
      title = 'Rising Star';
      titleHi = 'उभरता सितारा';
    } else if (score >= 40) {
      emoji = '💪';
      title = 'On Track';
      titleHi = 'सही राह पर';
    } else if (score > 0) {
      emoji = '🚀';
      title = 'Getting Started';
      titleHi = 'शुरुआत हो गई';
    } else {
      emoji = '🌱';
      title = 'Fresh Start';
      titleHi = 'नई शुरुआत';
    }

    // salaah (sabse zaroori 3)
    final tips = <WeekTip>[];
    if (activeDays < 4) {
      tips.add(const WeekTip('Study at least 5 days a week to build a habit.', 'आदत बनाने के लिए हफ़्ते में कम से कम 5 दिन पढ़ें।'));
    }
    if (focusSec < 7 * 45 * 60) {
      tips.add(const WeekTip('Aim for 1 hour of Study Timer focus every day.', 'रोज़ स्टडी टाइमर से 1 घंटा फोकस करने का लक्ष्य रखें।'));
    }
    if (tests == 0) {
      tips.add(const WeekTip('Take at least one mock test or quiz to measure yourself.', 'खुद को परखने के लिए कम से कम 1 मॉक टेस्ट या क्विज़ दें।'));
    }
    if (weak != null) {
      tips.add(WeekTip('Revise $weak — your lowest accuracy this week.', '$weak दोहराएँ — इस हफ़्ते सबसे कम सटीकता।'));
    }
    if (topics == 0) {
      tips.add(const WeekTip('Tick syllabus topics to track your preparation.', 'तैयारी ट्रैक करने के लिए सिलेबस टॉपिक टिक करें।'));
    }
    if (speedTotals[0] == 0) {
      tips.add(const WeekTip('Try 1 Speed Maths round daily — calculation speed wins marks.', 'रोज़ 1 स्पीड मैथ्स राउंड खेलें — तेज़ गणना से नंबर बढ़ते हैं।'));
    }
    if (tips.isEmpty) {
      tips.add(const WeekTip('Excellent consistency! Keep the streak alive.', 'शानदार निरंतरता! स्ट्रीक बनाए रखें।'));
    }

    return WeeklyReport(
      dates: dates,
      questionsPerDay: qPerDay,
      focusSecPerDay: focusPerDay,
      active: active,
      questions: questions,
      prevQuestions: prevQuestions,
      focusSec: focusSec,
      prevFocusSec: prevFocus,
      tests: tests,
      avgScore: avgScore,
      accuracy: accuracy,
      strongSubject: strong,
      weakSubject: weak,
      topics: topics,
      speedRounds: speedTotals[0],
      speedCorrect: speedTotals[1],
      streak: streak,
      score: score,
      emoji: emoji,
      title: title,
      titleHi: titleHi,
      tips: tips.take(3).toList(),
    );
  }
}
