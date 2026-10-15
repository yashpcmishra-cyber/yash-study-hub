import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'mock_rank_service.dart';

// =============================================================================
//  StudyStore - sab "personal study" data sirf STUDENT KE PHONE me rehta hai.
//
//  Firestore me kuch bhi save nahi hota, isliye free plan ki reads/writes/
//  storage par ZERO asar. Yahan ye cheezein hain:
//    - 7-din ki streak
//    - Daily goal (aaj kitne sawal kiye)
//    - Exam countdown (exam ka naam + date)
//    - Galtiyan (mistake notebook) aur Saved (bookmark) sawal
//    - Mock test history (Progress screen ke liye)
//    - Daily Quiz ka aaj ka cache + "aaj ho gaya" nishaan
//
//  Galtiyan / Saved / History me 30 din se purani entries apne aap hat jaati
//  hain (keepDays).
// =============================================================================

/// 7 din ki streak. [days] = lagatar kitne din app khola (0 = abhi shuru nahi).
class StreakInfo {
  final int days;
  const StreakInfo(this.days);

  /// 7 dibbon me se kitne bhare (0..7). Din 7 par poore 7, din 8 par phir 1.
  int get filled => days <= 0 ? 0 : ((days - 1) % 7) + 1;

  /// Kitni baar 7 din ki streak poori hui.
  int get completedWeeks => days ~/ 7;

  /// Aaj hi 7vi streak poori hui?
  bool get justCompleted => days > 0 && days % 7 == 0;
}

class ExamTarget {
  final String name;
  final DateTime? date; // sirf date (time 00:00)
  const ExamTarget(this.name, this.date);

  bool get isSet => date != null;

  /// Exam me kitne din bache (aaj = 0). Exam nikal gaya to negative.
  int daysLeft() {
    final d = date;
    if (d == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.difference(today).inDays;
  }
}

/// Mistake notebook / bookmark ki ek entry.
class SavedQuestion {
  final String key;
  final MockQuestion question;
  final DateTime savedAt;
  final String subject;
  final String source; // kis test / quiz se aaya

  SavedQuestion({
    required this.key,
    required this.question,
    required this.savedAt,
    this.subject = '',
    this.source = '',
  });

  Map<String, dynamic> toMap() => {
        'k': key,
        'q': question.toMap(),
        't': savedAt.millisecondsSinceEpoch,
        's': subject,
        'src': source,
      };

  static SavedQuestion? fromMap(dynamic m) {
    try {
      if (m is! Map) return null;
      final q = MockQuestion.fromMap(Map<String, dynamic>.from(m['q'] as Map));
      if (q.text.trim().isEmpty || q.options.length < 2) return null;
      return SavedQuestion(
        key: (m['k'] ?? StudyStore.qKey(q)).toString(),
        question: q,
        savedAt: DateTime.fromMillisecondsSinceEpoch((m['t'] as num?)?.toInt() ?? 0),
        subject: (m['s'] ?? '').toString(),
        source: (m['src'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Ek mock test / quiz ka natija (Progress screen ke liye).
class TestRecord {
  final String title;
  final String subject; // khali = "General"
  final double marks;
  final double maxMarks;
  final int correct;
  final int wrong;
  final int skipped;
  final DateTime at;

  TestRecord({
    required this.title,
    required this.subject,
    required this.marks,
    required this.maxMarks,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.at,
  });

  int get attempted => correct + wrong;
  double get accuracy => attempted == 0 ? 0 : correct / attempted * 100;

  /// Marks / total marks, 0..100 (negative marks 0 maane jaate hain).
  double get scorePercent {
    if (maxMarks <= 0) return 0;
    final p = marks / maxMarks * 100;
    if (p < 0) return 0;
    if (p > 100) return 100;
    return p;
  }

  Map<String, dynamic> toMap() => {
        'ti': title,
        's': subject,
        'm': marks,
        'x': maxMarks,
        'c': correct,
        'w': wrong,
        'k': skipped,
        't': at.millisecondsSinceEpoch,
      };

  static TestRecord? fromMap(dynamic m) {
    try {
      if (m is! Map) return null;
      return TestRecord(
        title: (m['ti'] ?? '').toString(),
        subject: (m['s'] ?? '').toString(),
        marks: (m['m'] as num?)?.toDouble() ?? 0,
        maxMarks: (m['x'] as num?)?.toDouble() ?? 0,
        correct: (m['c'] as num?)?.toInt() ?? 0,
        wrong: (m['w'] as num?)?.toInt() ?? 0,
        skipped: (m['k'] as num?)?.toInt() ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch((m['t'] as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return null;
    }
  }
}

class QuizDone {
  final String day; // quiz ki date (yyyy-MM-dd)
  final int score;
  final int total;
  const QuizDone(this.day, this.score, this.total);
}

class StudyStore {
  StudyStore._();

  /// Itne din baad purani entries hat jaati hain.
  static const int keepDays = 30;
  static const int _maxMistakes = 100;
  static const int _maxBookmarks = 100;
  static const int _maxHistory = 60;
  static const int defaultGoal = 20;

  static const _kStreak = 'ysh2_streak';
  static const _kStreakLast = 'ysh2_streak_last';
  static const _kGoalTarget = 'ysh2_goal_target';
  static const _kGoalDay = 'ysh2_goal_day';
  static const _kGoalDone = 'ysh2_goal_done';
  static const _kExamName = 'ysh2_exam_name';
  static const _kExamDate = 'ysh2_exam_date';
  static const _kMistakes = 'ysh2_mistakes';
  static const _kBookmarks = 'ysh2_bookmarks';
  static const _kHistory = 'ysh2_history';
  static const _kQuizDone = 'ysh2_quiz_done';
  static const _kQuizCache = 'ysh2_quiz_cache';

  /// Kuch badla to ye number badhta hai - Home ka card isse apne aap refresh hota hai.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  // ---------------------------------------------------------------- dates

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Phone ki aaj ki date, yyyy-MM-dd.
  static String today() => _dayKey(DateTime.now());

  /// Phone ki kal ki date, yyyy-MM-dd.
  static String yesterday() {
    final n = DateTime.now();
    return _dayKey(DateTime(n.year, n.month, n.day - 1));
  }

  static bool _fresh(DateTime at) => DateTime.now().difference(at) < const Duration(days: keepDays);

  // --------------------------------------------------------------- streak

  /// Aaj ka din gin leta hai (Home khulne par ek baar). Kal khola tha to
  /// streak +1, warna 1 se dobara shuru.
  static Future<StreakInfo> touchToday() async {
    final p = await SharedPreferences.getInstance();
    final t = today();
    final last = p.getString(_kStreakLast);
    var days = p.getInt(_kStreak) ?? 0;
    if (last != t) {
      days = (last == yesterday()) ? days + 1 : 1;
      await p.setString(_kStreakLast, t);
      await p.setInt(_kStreak, days);
    }
    return StreakInfo(days);
  }

  /// Sirf padhta hai. Streak toot chuki ho (kal-aaj dono nahi khola) to 0.
  static Future<StreakInfo> readStreak() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getString(_kStreakLast);
    if (last != today() && last != yesterday()) return const StreakInfo(0);
    return StreakInfo(p.getInt(_kStreak) ?? 0);
  }

  // ----------------------------------------------------------------- goal

  static Future<int> goalTarget() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_kGoalTarget) ?? defaultGoal;
    return v < 1 ? defaultGoal : v;
  }

  static Future<void> setGoalTarget(int n) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kGoalTarget, n < 1 ? defaultGoal : n);
    _bump();
  }

  /// Aaj kitne sawal kiye.
  static Future<int> goalDoneToday() async {
    final p = await SharedPreferences.getInstance();
    if (p.getString(_kGoalDay) != today()) return 0;
    return p.getInt(_kGoalDone) ?? 0;
  }

  static Future<void> addGoalProgress(int n) async {
    if (n <= 0) return;
    final p = await SharedPreferences.getInstance();
    final t = today();
    final done = p.getString(_kGoalDay) == t ? (p.getInt(_kGoalDone) ?? 0) : 0;
    await p.setString(_kGoalDay, t);
    await p.setInt(_kGoalDone, done + n);
    _bump();
  }

  // ---------------------------------------------------------------- exam

  static Future<ExamTarget> readExam() async {
    final p = await SharedPreferences.getInstance();
    final name = (p.getString(_kExamName) ?? '').trim();
    final raw = p.getString(_kExamDate);
    DateTime? date;
    if (raw != null && raw.length == 10) {
      final parts = raw.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) date = DateTime(y, m, d);
      }
    }
    return ExamTarget(name, date);
  }

  static Future<void> saveExam(String name, DateTime date) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kExamName, name.trim());
    await p.setString(_kExamDate, _dayKey(date));
    _bump();
  }

  static Future<void> clearExam() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kExamName);
    await p.remove(_kExamDate);
    _bump();
  }

  // ------------------------------------------------- question list helpers

  /// Sawal ki pehchaan (same sawal dobara aaye to duplicate na bane).
  static String qKey(MockQuestion q) {
    var h = 0x811c9dc5;
    final s = '${q.text}|${q.options.join('|')}|${q.textHi}';
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  static Future<List<SavedQuestion>> _loadQuestions(String prefKey) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(prefKey);
    if (raw == null || raw.isEmpty) return <SavedQuestion>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <SavedQuestion>[];
      for (final e in list) {
        final s = SavedQuestion.fromMap(e);
        if (s != null && _fresh(s.savedAt)) out.add(s);
      }
      return out;
    } catch (_) {
      return <SavedQuestion>[];
    }
  }

  static Future<void> _saveQuestions(String prefKey, List<SavedQuestion> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(prefKey, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  // ------------------------------------------------------------ mistakes

  /// Naye se purana (sabse nayi galti sabse upar).
  static Future<List<SavedQuestion>> mistakes() => _loadQuestions(_kMistakes);

  static Future<void> addMistakes(List<MockQuestion> qs, {String subject = '', String source = ''}) async {
    if (qs.isEmpty) return;
    final list = await _loadQuestions(_kMistakes);
    final now = DateTime.now();
    for (final q in qs) {
      final k = qKey(q);
      list.removeWhere((e) => e.key == k);
      list.insert(0, SavedQuestion(key: k, question: q, savedAt: now, subject: subject, source: source));
    }
    if (list.length > _maxMistakes) list.removeRange(_maxMistakes, list.length);
    await _saveQuestions(_kMistakes, list);
    _bump();
  }

  static Future<void> removeMistake(String key) async {
    final list = await _loadQuestions(_kMistakes);
    list.removeWhere((e) => e.key == key);
    await _saveQuestions(_kMistakes, list);
    _bump();
  }

  // ----------------------------------------------------------- bookmarks

  static Future<List<SavedQuestion>> bookmarks() => _loadQuestions(_kBookmarks);

  static Future<Set<String>> bookmarkKeys() async => (await bookmarks()).map((e) => e.key).toSet();

  /// Save / unsave. Naya state (true = ab saved hai) lautata hai.
  static Future<bool> toggleBookmark(MockQuestion q, {String subject = '', String source = ''}) async {
    final list = await _loadQuestions(_kBookmarks);
    final k = qKey(q);
    final had = list.any((e) => e.key == k);
    if (had) {
      list.removeWhere((e) => e.key == k);
    } else {
      list.insert(0, SavedQuestion(key: k, question: q, savedAt: DateTime.now(), subject: subject, source: source));
      if (list.length > _maxBookmarks) list.removeRange(_maxBookmarks, list.length);
    }
    await _saveQuestions(_kBookmarks, list);
    _bump();
    return !had;
  }

  static Future<void> removeBookmark(String key) async {
    final list = await _loadQuestions(_kBookmarks);
    list.removeWhere((e) => e.key == key);
    await _saveQuestions(_kBookmarks, list);
    _bump();
  }

  // ------------------------------------------------------------- history

  /// Naye se purana.
  static Future<List<TestRecord>> history() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHistory);
    if (raw == null || raw.isEmpty) return <TestRecord>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <TestRecord>[];
      for (final e in list) {
        final r = TestRecord.fromMap(e);
        if (r != null && _fresh(r.at)) out.add(r);
      }
      return out;
    } catch (_) {
      return <TestRecord>[];
    }
  }

  static Future<void> _addRecord(TestRecord r) async {
    final list = await history();
    list.insert(0, r);
    if (list.length > _maxHistory) list.removeRange(_maxHistory, list.length);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHistory, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  // -------------------------------------------------- results (mock / quiz)

  /// Mock test ka result aate hi Scorecard screen ye call karti hai:
  /// history me jodta hai, galat sawal notebook me daalta hai, goal badhata hai.
  static Future<void> recordMockResult({
    required MockTestModel test,
    required List<int?> answers,
    required MockResult result,
  }) async {
    try {
      final wrong = <MockQuestion>[];
      for (var i = 0; i < test.questions.length; i++) {
        final given = i < answers.length ? answers[i] : null;
        if (given != null && given != test.questions[i].correctIndex) wrong.add(test.questions[i]);
      }
      await _addRecord(TestRecord(
        title: test.title,
        subject: test.subject.trim(),
        marks: result.marks,
        maxMarks: result.maxMarks,
        correct: result.correct,
        wrong: result.wrong,
        skipped: result.unattempted,
        at: DateTime.now(),
      ));
      await addMistakes(wrong, subject: test.subject.trim(), source: test.title);
      await addGoalProgress(result.correct + result.wrong);
      _bump();
    } catch (_) {
      // Study data kabhi result screen ko rokna nahi chahiye.
    }
  }

  /// Daily Quiz poora hone par. Pehli baar (aaj) hi goal / history me gina jaata hai.
  static Future<void> recordDailyQuiz({
    required String day,
    required List<MockQuestion> questions,
    required List<int?> answers,
  }) async {
    try {
      var correct = 0;
      var wrong = 0;
      final wrongQs = <MockQuestion>[];
      for (var i = 0; i < questions.length; i++) {
        final given = i < answers.length ? answers[i] : null;
        if (given == null) continue;
        if (given == questions[i].correctIndex) {
          correct++;
        } else {
          wrong++;
          wrongQs.add(questions[i]);
        }
      }
      final already = await quizDone();
      final firstTime = already == null || already.day != day;
      if (firstTime) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kQuizDone, '$day|$correct|${questions.length}');
        await _addRecord(TestRecord(
          title: 'Daily Quiz',
          subject: 'Daily Quiz',
          marks: correct.toDouble(),
          maxMarks: questions.length.toDouble(),
          correct: correct,
          wrong: wrong,
          skipped: questions.length - correct - wrong,
          at: DateTime.now(),
        ));
        await addGoalProgress(correct + wrong);
      }
      await addMistakes(wrongQs, subject: 'Daily Quiz', source: 'Daily Quiz $day');
      _bump();
    } catch (_) {}
  }

  /// Practice (notebook se) ke baad: sahi kiye sawal notebook se hat jaate hain,
  /// kiye hue sawal goal me gine jaate hain.
  static Future<void> recordPractice({
    required List<SavedQuestion> items,
    required List<int?> answers,
    required bool removeCorrectFromMistakes,
  }) async {
    try {
      var answered = 0;
      for (var i = 0; i < items.length; i++) {
        final given = i < answers.length ? answers[i] : null;
        if (given == null) continue;
        answered++;
        if (removeCorrectFromMistakes && given == items[i].question.correctIndex) {
          await removeMistake(items[i].key);
        }
      }
      await addGoalProgress(answered);
      _bump();
    } catch (_) {}
  }

  // ----------------------------------------------------------- daily quiz

  static Future<QuizDone?> quizDone() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kQuizDone);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final s = int.tryParse(parts[1]);
    final t = int.tryParse(parts[2]);
    if (s == null || t == null) return null;
    return QuizDone(parts[0], s, t);
  }

  /// Quiz ka phone me rakha hua copy (taaki roz sirf 1 read lage).
  static Future<String?> readQuizCache() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kQuizCache);
  }

  static Future<void> writeQuizCache(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kQuizCache, json);
  }
}
