import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'study_store.dart';

/// Aaj ka Daily Quiz.
class DailyQuiz {
  final String day; // quiz ki date (yyyy-MM-dd)
  final List<MockQuestion> questions;
  const DailyQuiz(this.day, this.questions);

  Map<String, dynamic> toJson() => {'day': day, 'questions': questions.map((q) => q.toMap()).toList()};
}

/// Daily Quiz ko GitHub Action roz subah (~6 baje) PIB Current Affairs se
/// banakar Firestore me ek document me rakhta hai:
///     dailyCA/quiz_{yyyy-MM-dd}   ->  { qdate, questions: [ ... ] }
/// App roz sirf ISKO 1 baar padhta hai (1 read) aur phone me cache kar leta hai.
/// 30 din baad Action ise Firestore se hata deta hai.
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

  /// Aaj ka quiz (na mile to kal ka). Kuch bhi na mile to null.
  /// Internet/permission ki dikkat ho aur phone me purana cache ho to wahi deta hai.
  Future<DailyQuiz?> load({bool force = false}) async {
    final t = StudyStore.today();
    final cached = _parseJson(await StudyStore.readQuizCache());
    if (!force && cached != null && cached.day == t) return cached;

    Object? error;
    for (final day in <String>[t, StudyStore.yesterday()]) {
      // Kal ka quiz pehle se cache me hai to dobara padhne ki zaroorat nahi.
      if (day != t && cached != null && cached.day == day) return cached;
      try {
        final doc = await _db.collection('dailyCA').doc('quiz_$day').get().timeout(const Duration(seconds: 12));
        if (!doc.exists) continue;
        final quiz = _fromData(day, doc.data()?['questions']);
        if (quiz == null) continue;
        await StudyStore.writeQuizCache(jsonEncode(quiz.toJson()));
        return quiz;
      } catch (e) {
        error = e;
        break;
      }
    }
    if (cached != null) return cached;
    if (error != null) throw error;
    return null;
  }
}
