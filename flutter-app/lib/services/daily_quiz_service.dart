import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'study_store.dart';

/// Ek din ka Daily Quiz (max 10 sawal).
class DailyQuiz {
  final String day; // quiz ki date (yyyy-MM-dd)
  final List<MockQuestion> questions;
  const DailyQuiz(this.day, this.questions);

  Map<String, dynamic> toJson() => {'day': day, 'questions': questions.map((q) => q.toMap()).toList()};
}

/// Daily Quiz ko GitHub Action roz subah (~6 baje) PIB Current Affairs se
/// banakar Firestore me ek document me rakhta hai:
///     dailyCA/quiz_{yyyy-MM-dd}   ->  { qdate, questions: [ ... ] }
/// Student pichhle 7 din (aaj + 6 din) ke quiz khel sakta hai. App har din ka
/// quiz sirf 1 baar padhta hai (1 read) aur phone me cache kar leta hai.
/// 8th din Action purana quiz Firestore se hata deta hai, aur app bhi use
/// apne cache se hata deta hai ([StudyStore.purgeOldQuizData]).
class DailyQuizService {
  final _db = FirebaseFirestore.instance;

  static DailyQuiz? _parseJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _fromData((m['day'] ?? '').toString(), m['questions']);
    } catch (_) {
      return null;
    }
  }

  static DailyQuiz? _fromData(String day, dynamic raw) {
    if (raw is! List) return null;
    final out = <MockQuestion>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final q = MockQuestion.fromMap(Map<String, dynamic>.from(e));
      if (q.text.trim().isEmpty || q.options.length != 4) continue;
      if (q.correctIndex < 0 || q.correctIndex > 3) continue;
      out.add(q);
    }
    if (out.isEmpty) return null;
    return DailyQuiz(day, out);
  }

  /// Ek din ka quiz (`day` = yyyy-MM-dd, pichhle 7 din ke andar). Us din ka quiz
  /// na ho to null. Phone me cache ho to wahi deta hai (force = true par dobara padhta hai).
  /// Internet/permission ki dikkat ho aur cache ho to cache deta hai, warna error.
  Future<DailyQuiz?> loadDay(String day, {bool force = false}) async {
    if (!StudyStore.quizDayKeys().contains(day)) return null; // 7 din se purana
    final cached = _parseJson(await StudyStore.readQuizCacheDay(day));
    if (!force && cached != null) return cached;
    try {
      final doc = await _db.collection('dailyCA').doc('quiz_$day').get().timeout(const Duration(seconds: 12));
      if (!doc.exists) return cached;
      final quiz = _fromData(day, doc.data()?['questions']);
      if (quiz == null) return cached;
      await StudyStore.writeQuizCacheDay(day, jsonEncode(quiz.toJson()));
      return quiz;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }
}
