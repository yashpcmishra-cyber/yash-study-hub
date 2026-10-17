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
//    - Daily Quiz ke pichhle 7 din ka cache + har din ka "ho gaya" nishaan
//      (8th din purana quiz phone se bhi hat jaata hai)
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
  static const int defaultGoal = 10;
  /// The only goal choices. (Daily Quiz itself has at most 10 questions/day;
  /// the rest of the goal is filled by Mock Tests / practice.)
  static const List<int> goalOptions = [10, 20, 30, 40, 50];

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
  // Purani (sirf 1 din wali) keys - ab sirf migration ke liye padhi / hatayi jaati hain.
  static const _kQuizDone = 'ysh2_quiz_done';
  static const _kQuizCache = 'ysh2_quiz_cache';
  // Nayi keys: {yyyy-MM-dd: ...} map, jisme sirf pichhle [quizDays] din rehte hain.
  static const _kQuizDoneMap = 'ysh2_quiz_done7';
  static const _kQuizCacheMap = 'ysh2_quiz_cache7';

  /// Daily Quiz itne din (aaj + pichhle 6 din) tak available rehta hai.
  static const int quizDays = 7;

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
    // Old saved values (e.g. 5) that are no longer an option fall back to the default 10.
    return goalOptions.contains(v) ? v : defaultGoal;
  }

  static Future<void> setGoalTarget(int n) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kGoalTarget, goalOptions.contains(n) ? n : defaultGoal);
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
      final already = await quizDoneFor(day);
      final firstTime = already == null;
      if (firstTime) {
        final p = await SharedPreferences.getInstance();
        final done = _pruneQuizDays(_decodeMap(p.getString(_kQuizDoneMap)));
        done[day] = '$correct|${questions.length}';
        await p.setString(_kQuizDoneMap, jsonEncode(done));
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

  /// Quiz ke liye pichhle [quizDays] din ki date keys (aaj pehle), yyyy-MM-dd.
  static List<String> quizDayKeys() {
    final n = DateTime.now();
    return List<String>.generate(quizDays, (i) => _dayKey(DateTime(n.year, n.month, n.day - i)));
  }

  static Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final m = jsonDecode(raw);
      if (m is Map) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// 7 din se purani date wali entries hata deta hai.
  static Map<String, dynamic> _pruneQuizDays(Map<String, dynamic> m) {
    final keep = quizDayKeys().toSet();
    m.removeWhere((k, _) => !keep.contains(k));
    return m;
  }

  /// Aaj ka quiz ho gaya? (Home ka red dot isse chalta hai.)
  static Future<QuizDone?> quizDone() => quizDoneFor(today());

  /// Us din ka quiz ho gaya? Nahi to null.
  static Future<QuizDone?> quizDoneFor(String day) async {
    final p = await SharedPreferences.getInstance();
    final v = _decodeMap(p.getString(_kQuizDoneMap))[day];
    if (v is String) {
      final parts = v.split('|');
      final s = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final t = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (s != null && t != null) return QuizDone(day, s, t);
    }
    // Purana format (day|score|total) - update se pehle ka aaj ka result.
    final old = p.getString(_kQuizDone)?.split('|');
    if (old != null && old.length == 3 && old[0] == day) {
      final s = int.tryParse(old[1]);
      final t = int.tryParse(old[2]);
      if (s != null && t != null) return QuizDone(day, s, t);
    }
    return null;
  }

  /// Un dino ki date keys jinka quiz ho chuka hai (chips par tick ke liye).
  static Future<Set<String>> quizDoneDays() async {
    final p = await SharedPreferences.getInstance();
    final out = _pruneQuizDays(_decodeMap(p.getString(_kQuizDoneMap))).keys.toSet();
    final old = p.getString(_kQuizDone)?.split('|');
    if (old != null && old.length == 3 && quizDayKeys().contains(old[0])) out.add(old[0]);
    return out;
  }

  /// Us din ke quiz ka phone me rakha hua copy (taaki baar-baar read na lage).
  static Future<String?> readQuizCacheDay(String day) async {
    final p = await SharedPreferences.getInstance();
    final v = _pruneQuizDays(_decodeMap(p.getString(_kQuizCacheMap)))[day];
    return v is String ? v : null;
  }

  static Future<void> writeQuizCacheDay(String day, String json) async {
    final p = await SharedPreferences.getInstance();
    final m = _pruneQuizDays(_decodeMap(p.getString(_kQuizCacheMap)));
    if (!quizDayKeys().contains(day)) return;
    m[day] = json;
    await p.setString(_kQuizCacheMap, jsonEncode(m));
  }

  /// 7 din se purana quiz cache / result phone se hata deta hai
  /// (aur purani 1-din wali keys bhi). Daily Quiz screen khulte hi chalta hai.
  static Future<void> purgeOldQuizData() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cache = _decodeMap(p.getString(_kQuizCacheMap));
      final cacheKept = _pruneQuizDays(Map<String, dynamic>.from(cache));
      if (cacheKept.length != cache.length) await p.setString(_kQuizCacheMap, jsonEncode(cacheKept));
      final done = _decodeMap(p.getString(_kQuizDoneMap));
      final doneKept = _pruneQuizDays(Map<String, dynamic>.from(done));
      if (doneKept.length != done.length) await p.setString(_kQuizDoneMap, jsonEncode(doneKept));
      await p.remove(_kQuizCache);
      // Purana _kQuizDone sirf tab rakho jab uski date 7 din ke andar ho.
      final old = p.getString(_kQuizDone)?.split('|');
      if (old != null && !quizDayKeys().contains(old.first)) await p.remove(_kQuizDone);
    } catch (_) {}
  }
}
