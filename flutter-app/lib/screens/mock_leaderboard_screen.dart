import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../services/mock_rank_service.dart' show fmtMarks;
import '../widgets/state_views.dart';

const _cardBg = Color(0xFF101D57);
const _gold = Color(0xFFFFFF29);

/// Ek mock test ki Leaderboard - SIRF marks ke hisaab se rank list.
/// Kisi student ka naam / email / photo yahan nahi aata.
class MockLeaderboardScreen extends StatefulWidget {
  final String testId;
  final String testTitle;

  /// true = cache ignore karke taaza data (result ke turant baad ke liye)
  final bool refreshOnOpen;

  const MockLeaderboardScreen({
    super.key,
    required this.testId,
    required this.testTitle,
    this.refreshOnOpen = false,
  });

  @override
  State<MockLeaderboardScreen> createState() => _MockLeaderboardScreenState();
}

class _MockLeaderboardScreenState extends State<MockLeaderboardScreen> {
  final _svc = LeaderboardService();
  late Future<LeaderboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.load(widget.testId, force: widget.refreshOnOpen);
  }

  Future<void> _refresh() async {
    final f = _svc.load(widget.testId, force: true);
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: FutureBuilder<LeaderboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(children: [SizedBox(height: 420, child: ErrorView(error: snap.error))]),
            );
          }
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(LeaderboardData d) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.testTitle,
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${d.total} ${d.total == 1 ? 'student' : 'students'} ne ye test diya',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          _myCard(d),
          const SizedBox(height: 14),
          if (d.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: EmptyView('Abhi kisi ne ye test nahi diya.\nPehle aap bano! 🏆'),
            )
          else ...[
            const Text('Top ranks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            for (final r in d.rows) _row(r),
          ],
          const SizedBox(height: 12),
          const Text(
            'Rank sirf marks se tay hota hai — naam kisi ka nahi dikhta. Barabar marks = barabar rank. '
            'Pehle attempt ke marks gine jaate hain. Data 30 din baad hat jaata hai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _myCard(LeaderboardData d) {
    final has = d.myRank != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: has
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _big('#${d.myRank}', 'Aapka rank'),
                _big(fmtMarks(d.myMarks ?? 0), 'Aapke marks'),
              ],
            )
          : const Text(
              'Aapne ye test abhi nahi diya. Test dene ke baad yahan aapka rank dikhega.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF081136), fontSize: 13, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _big(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Color(0xFF081136), fontWeight: FontWeight.bold, fontSize: 26)),
      Text(label, style: const TextStyle(color: Color(0xFF101D57), fontSize: 12)),
    ]);
  }

  Widget _row(LeaderRow r) {
    final medal = r.rank == 1 ? '🥇' : (r.rank == 2 ? '🥈' : (r.rank == 3 ? '🥉' : ''));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: r.isMe ? const Color(0x33FFFF29) : _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.isMe ? _gold : Colors.transparent),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(medal.isEmpty ? '#${r.rank}' : '$medal  #${r.rank}',
                style: TextStyle(color: r.rank <= 3 ? _gold : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: Text(r.isMe ? 'You' : '', style: TextStyle(color: r.isMe ? _gold : Colors.white38, fontSize: 13, fontWeight: r.isMe ? FontWeight.bold : FontWeight.normal)),
          ),
          Text('${fmtMarks(r.marks)} marks', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
