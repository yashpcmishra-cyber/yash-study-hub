import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Leaderboard ki ek line. NAAM / EMAIL kuch nahi - sirf rank aur marks.
class LeaderRow {
  final int rank; // same marks = same rank
  final double marks;
  final bool isMe; // sirf is phone ke student ko "You" dikhane ke liye
  const LeaderRow(this.rank, this.marks, this.isMe);
}

class LeaderboardData {
  final List<LeaderRow> rows; // upar ke topN
  final int total; // is test ko kitno ne diya
  final int? myRank; // null = is student ne ye test abhi diya nahi
  final double? myMarks;
  final DateTime fetchedAt;
  const LeaderboardData({
    required this.rows,
    required this.total,
    required this.myRank,
    required this.myMarks,
    required this.fetchedAt,
  });
}

/// Test ki leaderboard: sirf marks ke hisaab se rank list.
///
/// Data wahi hai jo rank ke liye pehle se banta hai:
///     mockScores/{testId}/scores/{uid}  ->  { score, timeSec, at }
/// Isme naam / email save hi nahi hota, isliye leaderboard me naam aa hi nahi
/// sakte. Koi naya collection ya naya write nahi - sirf padhna.
///
/// Free plan ke liye: ek baar kholne par ~topN + 2 reads lagte hain, aur 3
/// minute tak wahi result phone me yaad rakha jaata hai (dobara kholne par 0).
/// "scores" ke docs 30 din baad cleanup-scores Action hata deta hai.
class LeaderboardService {
  static const int topN = 20;
  static const Duration _ttl = Duration(minutes: 3);
  static final Map<String, LeaderboardData> _cache = <String, LeaderboardData>{};

  Future<LeaderboardData> load(String testId, {bool force = false}) async {
    final hit = _cache[testId];
    if (!force && hit != null && DateTime.now().difference(hit.fetchedAt) < _ttl) return hit;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final col = FirebaseFirestore.instance.collection('mockScores').doc(testId).collection('scores');

    final snap = await col.orderBy('score', descending: true).limit(topN).get().timeout(const Duration(seconds: 15));

    final rows = <LeaderRow>[];
    double? prevMarks;
    var prevRank = 0;
    int? myRank;
    double? myMarks;
    for (var i = 0; i < snap.docs.length; i++) {
      final d = snap.docs[i];
      final raw = d.data()['score'];
      final marks = raw is num ? raw.toDouble() : 0.0;
      final rank = (prevMarks != null && marks == prevMarks) ? prevRank : i + 1;
      final me = uid != null && d.id == uid;
      rows.add(LeaderRow(rank, marks, me));
      if (me) {
        myRank = rank;
        myMarks = marks;
      }
      prevMarks = marks;
      prevRank = rank;
    }

    var total = rows.length;
    try {
      final agg = await col.count().get().timeout(const Duration(seconds: 15));
      final c = agg.count ?? rows.length;
      if (c > total) total = c;
    } catch (_) {
      // total na mile to sirf dikhai gayi list ki ginti rakhte hain
    }

    // Student top list me nahi hai, par usne test diya hai -> uska rank alag se nikalo.
    if (myRank == null && uid != null) {
      try {
        final mine = await col.doc(uid).get().timeout(const Duration(seconds: 15));
        if (mine.exists) {
          final raw = mine.data()?['score'];
          final marks = raw is num ? raw.toDouble() : 0.0;
          final higher = await col.where('score', isGreaterThan: marks).count().get().timeout(const Duration(seconds: 15));
          myRank = (higher.count ?? 0) + 1;
          myMarks = marks;
        }
      } catch (_) {
        // rank "—" rahega, list phir bhi dikhegi
      }
    }

    final data = LeaderboardData(rows: rows, total: total, myRank: myRank, myMarks: myMarks, fetchedAt: DateTime.now());
    _cache[testId] = data;
    return data;
  }
}
