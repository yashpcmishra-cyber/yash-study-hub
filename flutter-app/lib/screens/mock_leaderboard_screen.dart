import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../services/mock_rank_service.dart' show fmtMarks;
import '../widgets/state_views.dart';

import '../app_colors.dart';

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
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${d.total} ${d.total == 1 ? 'student has' : 'students have'} taken this test / ${d.total} छात्रों ने यह टेस्ट दिया',
              textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 12)),
          const SizedBox(height: 12),
          _myCard(d),
          const SizedBox(height: 14),
          if (d.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: EmptyView('No one has taken this test yet.\nBe the first! 🏆\n\nअभी किसी ने यह टेस्ट नहीं दिया।\nपहले आप बनें! 🏆'),
            )
          else ...[
            Text('Top ranks', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            for (final r in d.rows) _row(r),
          ],
          const SizedBox(height: 12),
          Text(
            'Rank depends only on marks \u2014 no names are shown. Equal marks = equal rank. '
            'The first attempt\u2019s marks are counted. Data is removed after 30 days.\n'
            'रैंक केवल अंकों से तय होती है — नाम नहीं दिखते। बराबर अंक = बराबर रैंक। पहले प्रयास के अंक गिने जाते हैं। डेटा 30 दिन बाद हट जाता है।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.4),
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
                _big('#${d.myRank}', 'Your rank / आपकी रैंक'),
                _big(fmtMarks(d.myMarks ?? 0), 'Your marks / आपके अंक'),
              ],
            )
          : const Text(
              'You have not taken this test yet. Your rank will appear here after you take it.\nआपने यह टेस्ट अभी नहीं दिया है। टेस्ट देने के बाद आपकी रैंक यहाँ दिखेगी।',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppC.onGold, fontSize: 13, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _big(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 26)),
      Text(label, style: const TextStyle(color: AppC.onGold, fontSize: 12)),
    ]);
  }

  Widget _row(LeaderRow r) {
    final medal = r.rank == 1 ? '🥇' : (r.rank == 2 ? '🥈' : (r.rank == 3 ? '🥉' : ''));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: r.isMe ? AppC.goldWash2 : AppC.card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.isMe ? AppC.accent : Colors.transparent),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(medal.isEmpty ? '#${r.rank}' : '$medal  #${r.rank}',
                style: TextStyle(color: r.rank <= 3 ? AppC.accent : AppC.text70, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: Text(r.isMe ? 'You' : '', style: TextStyle(color: r.isMe ? AppC.accent : AppC.text38, fontSize: 13, fontWeight: r.isMe ? FontWeight.bold : FontWeight.normal)),
          ),
          Text('${fmtMarks(r.marks)} marks', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
