import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

// ---------- Chhote helpers (attempt + result dono screen use karte hain) ----------

/// Hindi chuna ho aur Hindi text ho to Hindi, warna English.
String mockText(MockQuestion q, bool hi) => (hi && q.textHi.trim().isNotEmpty) ? q.textHi : q.text;

List<String> mockOptions(MockQuestion q, bool hi) =>
    (hi && q.optionsHi.length == q.options.length) ? q.optionsHi : q.options;

String mockExplanation(MockQuestion q, bool hi) =>
    (hi && q.explanationHi.trim().isNotEmpty) ? q.explanationHi : q.explanation;

/// Kisi bhi question me Hindi ho to hi toggle dikhega. Purane tests me nahi.
bool mockHasHindi(MockTestModel t) => t.questions.any((q) => q.textHi.trim().isNotEmpty);

/// 12.0 -> "12", 12.5 -> "12.5", 0.25 -> "0.25"
String fmtMarks(double v) {
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.round().toString();
  var s = r.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

/// 75 -> "01:15", 3700 -> "1:01:40"
String fmtDuration(int sec) {
  if (sec < 0) sec = 0;
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

// ---------- Result ----------

class MockResult {
  final int correct;
  final int wrong;
  final int unattempted;
  final int total;
  final double marks; // negative marking ke baad
  final double maxMarks;
  final double accuracy; // sahi / attempted * 100

  MockResult({
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.total,
    required this.marks,
    required this.maxMarks,
    required this.accuracy,
  });

  static MockResult compute(MockTestModel t, List<int?> answers) {
    var correct = 0;
    var wrong = 0;
    var skipped = 0;
    for (var i = 0; i < t.questions.length; i++) {
      final given = i < answers.length ? answers[i] : null;
      if (given == null) {
        skipped++;
      } else if (given == t.questions[i].correctIndex) {
        correct++;
      } else {
        wrong++;
      }
    }
    final raw = correct * t.marksPerQuestion - wrong * t.negativeMarks;
    final marks = (raw * 100).round() / 100;
    final maxMarks = ((t.questions.length * t.marksPerQuestion) * 100).round() / 100;
    final attempted = correct + wrong;
    final acc = attempted == 0 ? 0.0 : (correct / attempted) * 100;
    return MockResult(
      correct: correct,
      wrong: wrong,
      unattempted: skipped,
      total: t.questions.length,
      marks: marks,
      maxMarks: maxMarks,
      accuracy: acc,
    );
  }
}

// ---------- Rank ----------

class MockRankInfo {
  final int rank;
  final int total; // is test ko kitno ne diya (pehle attempt walon me)
  final bool firstAttempt; // false = retake, rank pehle attempt ke score se
  final double countedMarks; // rank jis score par bana
  MockRankInfo({required this.rank, required this.total, required this.firstAttempt, required this.countedMarks});
}

/// Collection: mockScores/{testId}/scores/{uid}  ->  {score, timeSec, at}
/// Naam / email yaha save NAHI hota. Doc id = Firebase uid, isliye ek student
/// ka ek hi score (pehla attempt) ginta hai. Retake par naya score save nahi hota.
/// Rank = (is test me kitno ka score zyada) + 1.
class MockRankService {
  final _db = FirebaseFirestore.instance;

  /// Kuch bhi fail ho (offline, rules, timeout) to null deta hai - result screen
  /// phir bhi chalti hai, bas rank "—" dikhta hai.
  Future<MockRankInfo?> submitAndGetRank({
    required String testId,
    required double marks,
    required int timeSec,
  }) async {
    try {
      return await _run(testId, marks, timeSec).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  Future<MockRankInfo?> _run(String testId, double marks, int timeSec) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || testId.isEmpty) return null;

    final col = _db.collection('mockScores').doc(testId).collection('scores');
    final ref = col.doc(uid);

    final existing = await ref.get();
    double counted;
    bool first;
    if (existing.exists) {
      final old = existing.data()?['score'];
      counted = old is num ? old.toDouble() : marks;
      first = false;
    } else {
      await ref.set({
        'score': marks,
        'timeSec': timeSec,
        'at': FieldValue.serverTimestamp(),
      });
      counted = marks;
      first = true;
    }

    final higher = await col.where('score', isGreaterThan: counted).count().get();
    final all = await col.count().get();
    final higherCount = higher.count ?? 0;
    final allCount = all.count ?? 0;
    return MockRankInfo(
      rank: higherCount + 1,
      total: allCount < higherCount + 1 ? higherCount + 1 : allCount,
      firstAttempt: first,
      countedMarks: counted,
    );
  }
}
