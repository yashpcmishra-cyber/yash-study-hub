import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/revision_store.dart';
import '../widgets/state_views.dart';
import 'mock_test_attempt_screen.dart';
import 'quiz_session_screen.dart';

/// Smart Revision: Mistake Notebook ke galat sawal 1 -> 3 -> 7 -> 15 din ke gap par
/// dobara puchhe jaate hain (spaced repetition). 4 baar sahi = sawal pakka.
/// Topic-wise Mock: har topic (subject) ke saare galat sawal MCQ ki tarah ek
/// asli Mock Test (timer, question palette, scorecard) me attempt hote hain.
/// Schedule sirf phone me hai - Firestore ko 0 reads / 0 writes.
class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  RevisionOverview? _ov;
  List<RevisionTopic> _topics = const <RevisionTopic>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await RevisionStore.overview();
      final topics = await RevisionStore.topics();
      if (!mounted) return;
      setState(() {
        _ov = o;
        _topics = topics;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ov = const RevisionOverview());
    }
  }

  Future<void> _start({required bool scheduled}) async {
    final items = scheduled ? await RevisionStore.dueItems() : await RevisionStore.extraItems();
    if (items.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: scheduled ? 'Revision / रिवीज़न' : 'Extra practice / एक्स्ट्रा प्रैक्टिस',
        questions: items.map((e) => e.question).toList(),
        onFinished: (answers) => RevisionStore.recordSession(items: items, answers: answers, scheduled: scheduled),
      ),
    ));
    if (mounted) _load();
  }

  /// Topic ke saare galat sawal ka Mock (MCQ format). Result sirf phone me jaata hai.
  Future<void> _startMock(RevisionTopic t) async {
    if (t.items.isEmpty || !mounted) return;
    final test = RevisionStore.buildMock(t.name, t.items);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MockTestAttemptScreen(test: test, revisionItems: t.items),
    ));
    if (mounted) _load();
  }

  String _nextLabel(String d) {
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
    if (diff <= 1) return 'tomorrow / कल';
    return 'in $diff days / $diff दिन बाद';
  }

  @override
  Widget build(BuildContext context) {
    final ov = _ov;
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Revision')),
      body: ov == null ? const LoadingView() : _content(ov),
    );
  }

  Widget _content(RevisionOverview ov) {
    final hasDue = ov.due > 0;
    final String big;
    final String line1;
    final String line2;
    if (ov.total == 0) {
      big = '📓';
      line1 = 'No mistakes to revise yet.';
      line2 = 'अभी revision के लिए कोई गलती नहीं है।\nMock Test या Daily Quiz दीजिए।';
    } else if (hasDue) {
      big = '${ov.due}';
      line1 = 'questions ready for revision today';
      line2 = 'आज revision के लिए सवाल तैयार हैं';
    } else {
      big = '🎉';
      line1 = 'Today\u2019s revision is done!';
      line2 = ov.nextDue == null ? 'आज का revision पूरा हुआ!' : 'आज का revision पूरा! Next: ${_nextLabel(ov.nextDue!)}';
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(big, style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 44)),
                const SizedBox(height: 4),
                Text(line1, textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(line2, textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (hasDue)
            ElevatedButton.icon(
              onPressed: () => _start(scheduled: true),
              icon: const Icon(Icons.play_arrow),
              label: Text('Start revision (${ov.due > RevisionStore.sessionSize ? RevisionStore.sessionSize : ov.due}) / शुरू करें'),
            ),
          if (!hasDue && ov.total > 0)
            OutlinedButton.icon(
              onPressed: () => _start(scheduled: false),
              icon: const Icon(Icons.shuffle),
              label: const Text('Extra practice (10 random) / एक्स्ट्रा प्रैक्टिस'),
            ),
          if (hasDue && ov.due > RevisionStore.sessionSize)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '10 questions per round. Finish it and start again for the rest.\nएक राउंड में 10 सवाल। बाकी के लिए दोबारा शुरू करें।',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppC.muted, fontSize: 11.5),
              ),
            ),
          if (_topics.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Topic-wise Mock / टॉपिक वाइज़ मॉक', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'All your wrong questions of a topic as one timed mock test (MCQs).\nकिसी टॉपिक के सारे गलत सवाल एक टाइमर वाले मॉक टेस्ट (MCQ) में।',
              style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            for (final t in _topics) _topicTile(t),
          ],
          const SizedBox(height: 18),
          Text('Your revision steps / आपके revision स्टेप', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                for (var i = 0; i < RevisionStore.intervals.length; i++) _stepRow(i, ov),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mastered so far: ${ov.mastered} / अब तक पक्के: ${ov.mastered}',
                        style: TextStyle(color: AppC.text, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(12)),
            child: Text(
              '💡 How it works: every wrong question comes back after 1, 3, 7 and 15 days. '
              'Answer correctly and it moves to the next step; answer wrong and it starts again tomorrow. '
              'After 4 correct revisions it is mastered and leaves your revision list.\n\n'
              'कैसे काम करता है: हर गलत सवाल 1, 3, 7 और 15 दिन बाद दोबारा आता है। '
              'सही किया तो अगले स्टेप पर, गलत किया तो कल फिर से। '
              '4 बार सही होने पर सवाल पक्का हो जाता है और रिवीज़न लिस्ट से हट जाता है।',
              style: TextStyle(color: AppC.text, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Saved only on your phone.\nयह डेटा केवल आपके फ़ोन में है।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _topicTile(RevisionTopic t) {
    final mins = t.count < 5 ? 5 : t.count;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${t.count} Qs / सवाल  •  $mins min / मिनट${t.due > 0 ? '  •  ${t.due} due / बाकी' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppC.text70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _startMock(t),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            child: const Text('Start Mock'),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int i, RevisionOverview ov) {
    final count = ov.perBox[i];
    final ratio = ov.total == 0 ? 0.0 : (count / ov.total).clamp(0.0, 1.0).toDouble();
    final gap = RevisionStore.intervals[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Step ${i + 1} • $gap-day gap / $gap दिन का अंतराल',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppC.text, fontSize: 13),
                ),
              ),
              Text('$count Qs / सवाल', style: TextStyle(color: AppC.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: AppC.card, color: AppC.green),
          ),
        ],
      ),
    );
  }
}
