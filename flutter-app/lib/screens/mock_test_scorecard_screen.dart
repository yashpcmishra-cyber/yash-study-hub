import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/mock_rank_service.dart';

const _navy = Color(0xFF081136);
const _cardBg = Color(0xFF101D57);
const _gold = Color(0xFFFFFF29);

/// Result: marks (negative marking ke saath), accuracy, rank, sahi/galat/
/// unattempted aur har question ka explanation.
class MockTestScorecardScreen extends StatefulWidget {
  final MockTestModel test;
  final List<int?> answers;
  final int timeTakenSec;
  final bool autoSubmitted; // time khatam hone par khud submit hua
  final String? note; // e.g. "you are offline"

  const MockTestScorecardScreen({
    super.key,
    required this.test,
    required this.answers,
    this.timeTakenSec = 0,
    this.autoSubmitted = false,
    this.note,
  });

  @override
  State<MockTestScorecardScreen> createState() => _MockTestScorecardScreenState();
}

class _MockTestScorecardScreenState extends State<MockTestScorecardScreen> {
  late final MockResult _r;
  late final Future<MockRankInfo?> _rankFuture;
  late final bool _hasHindi;
  bool _hindi = false;

  @override
  void initState() {
    super.initState();
    _r = MockResult.compute(widget.test, widget.answers);
    _hasHindi = mockHasHindi(widget.test);
    // Rank ka kaam alag chalta hai - result turant dikhta hai, rank baad me aata hai.
    _rankFuture = MockRankService().submitAndGetRank(
      testId: widget.test.id,
      marks: _r.marks,
      timeSec: widget.timeTakenSec,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.test;
    final plus = _r.correct * t.marksPerQuestion;
    final minus = _r.wrong * t.negativeMarks;
    return Scaffold(
      appBar: AppBar(title: const Text('Result'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(t.title, textAlign: TextAlign.center, style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Text('${fmtMarks(_r.marks)} / ${fmtMarks(_r.maxMarks)}', style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 32)),
                const Text('Marks', style: TextStyle(color: Color(0xFF101D57), fontSize: 13)),
                if (t.negativeMarks > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+${fmtMarks(plus)}  \u2212${fmtMarks(minus)} (negative)',
                    style: const TextStyle(color: Color(0xFF101D57), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (widget.autoSubmitted) ...[
            const SizedBox(height: 10),
            const Text('Time is up \u2014 your test was submitted automatically.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12), textAlign: TextAlign.center),
          ],
          if (widget.note != null) ...[
            const SizedBox(height: 10),
            Text(widget.note!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 14),
          Row(children: [
            _rankTile(),
            const SizedBox(width: 8),
            _tile('Accuracy', '${_r.accuracy.toStringAsFixed(1)}%', Colors.white),
            const SizedBox(width: 8),
            _tile('Time', fmtDuration(widget.timeTakenSec), Colors.white),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _tile('Correct', '${_r.correct}', Colors.greenAccent),
            const SizedBox(width: 8),
            _tile('Wrong', '${_r.wrong}', Colors.redAccent),
            const SizedBox(width: 8),
            _tile('Unattempted', '${_r.unattempted}', Colors.grey),
          ]),
          _rankNote(),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
            if (_hasHindi)
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _langBtn('EN', !_hindi, () => setState(() => _hindi = false)),
                  _langBtn('\u0939\u093f\u0902', _hindi, () => setState(() => _hindi = true)),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < t.questions.length; i++) _reviewCard(i),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Back to Home')),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _rankTile() {
    return FutureBuilder<MockRankInfo?>(
      future: _rankFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
              child: const Column(children: [
                SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(height: 6),
                Text('Rank', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            ),
          );
        }
        final info = snap.data;
        return _tile('Rank', info == null ? '\u2014' : '#${info.rank} / ${info.total}', _gold);
      },
    );
  }

  Widget _rankNote() {
    return FutureBuilder<MockRankInfo?>(
      future: _rankFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final info = snap.data;
        String? text;
        if (info == null) {
          text = 'Rank is not available right now (check your internet).';
        } else if (!info.firstAttempt) {
          text = 'Retake: your rank is based on your first attempt (${fmtMarks(info.countedMarks)} marks).';
        }
        if (text == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        );
      },
    );
  }

  Widget _langBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: active ? _gold : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: active ? _navy : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _reviewCard(int i) {
    final q = widget.test.questions[i];
    final given = i < widget.answers.length ? widget.answers[i] : null;
    final correct = q.correctIndex;
    final opts = mockOptions(q, _hindi);
    final explanation = mockExplanation(q, _hindi).trim();

    final IconData icon;
    final Color iconColor;
    if (given == null) {
      icon = Icons.remove_circle_outline;
      iconColor = Colors.grey;
    } else if (given == correct) {
      icon = Icons.check_circle;
      iconColor = Colors.greenAccent;
    } else {
      icon = Icons.cancel;
      iconColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${i + 1}. ${mockText(q, _hindi)}', style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var oi = 0; oi < opts.length; oi++) _reviewOption(oi, opts[oi], correct, given),
          if (given == null) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Not attempted', style: TextStyle(color: Colors.grey, fontSize: 12))),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0x22FFFF29), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explanation', style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(explanation, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewOption(int oi, String text, int correct, int? given) {
    final isCorrect = oi == correct;
    final isGiven = oi == given;
    Color border = Colors.white12;
    Color textColor = Colors.white70;
    String mark = '';
    if (isCorrect) {
      border = Colors.greenAccent;
      textColor = Colors.greenAccent;
      mark = '  \u2713';
    } else if (isGiven) {
      border = Colors.redAccent;
      textColor = Colors.redAccent;
      mark = '  \u2717';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Text('${String.fromCharCode(65 + oi)}. $text$mark${isGiven ? '  (your answer)' : ''}',
          style: TextStyle(color: textColor, fontSize: 13)),
    );
  }
}
