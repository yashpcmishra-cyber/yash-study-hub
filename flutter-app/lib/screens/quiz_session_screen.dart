import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/mock_rank_service.dart';
import '../services/study_store.dart';
import '../widgets/di_image.dart';

const _navy = Color(0xFF081136);
const _cardBg = Color(0xFF101D57);
const _gold = Color(0xFFFFFF29);

/// Ek-ek sawal ka quiz, har jawab ke turant baad sahi/galat + explanation.
/// Daily Quiz aur Mistake Notebook ki practice - dono isi screen se chalte hain.
/// Natija [onFinished] ko diya jaata hai (wahi goal / notebook update karta hai).
/// Is screen se Firestore ko kuch nahi chhua jaata.
class QuizSessionScreen extends StatefulWidget {
  final String title;
  final List<MockQuestion> questions;
  final Future<void> Function(List<int?> answers) onFinished;
  final String bookmarkSource; // bookmark karne par "kahan se aaya" me dikhega

  const QuizSessionScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.onFinished,
    this.bookmarkSource = '',
  });

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  int _i = 0;
  int? _picked;
  late final List<int?> _answers = List<int?>.filled(widget.questions.length, null);
  bool _hindi = false;
  bool _finishing = false;
  bool _done = false;
  Set<String> _saved = <String>{};

  bool get _hasHindi => widget.questions.any((q) => q.textHi.trim().isNotEmpty);
  MockQuestion get _q => widget.questions[_i];

  @override
  void initState() {
    super.initState();
    StudyStore.bookmarkKeys().then((s) {
      if (mounted) setState(() => _saved = s);
    });
  }

  void _pick(int oi) {
    if (_picked != null) return;
    setState(() {
      _picked = oi;
      _answers[_i] = oi;
    });
  }

  Future<void> _next() async {
    if (_i < widget.questions.length - 1) {
      setState(() {
        _i++;
        _picked = null;
      });
      return;
    }
    setState(() => _finishing = true);
    try {
      await widget.onFinished(List<int?>.from(_answers));
    } catch (_) {
      // Natija save na bhi ho to student ko score dikhna chahiye.
    }
    if (mounted) setState(() {
      _finishing = false;
      _done = true;
    });
  }

  Future<void> _toggleSave() async {
    final q = _q;
    final nowSaved = await StudyStore.toggleBookmark(q, source: widget.bookmarkSource);
    if (!mounted) return;
    final key = StudyStore.qKey(q);
    setState(() {
      if (nowSaved) {
        _saved = {..._saved, key};
      } else {
        _saved = _saved.where((k) => k != key).toSet();
      }
    });
  }

  Future<bool> _confirmLeave() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Quiz beech me chhodna hai?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Abhi tak ka progress save nahi hoga. / अभी तक का प्रोग्रेस सेव नहीं होगा।', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Continue')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Exit', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = !_done && (_i > 0 || _picked != null);
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontSize: 16)),
          actions: [
            if (_hasHindi && !_done)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _langBtn('EN', !_hindi, () => setState(() => _hindi = false)),
                    _langBtn('हिं', _hindi, () => setState(() => _hindi = true)),
                  ]),
                ),
              ),
          ],
        ),
        body: _done ? _resultView() : _questionView(),
      ),
    );
  }

  Widget _langBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: active ? _gold : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: active ? _navy : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _questionView() {
    final q = _q;
    final total = widget.questions.length;
    final opts = mockOptions(q, _hindi);
    final passage = mockPassage(q, _hindi);
    final passageImg = q.passageImage.trim();
    final explanation = mockExplanation(q, _hindi).trim();
    final answered = _picked != null;
    final saved = _saved.contains(StudyStore.qKey(q));

    return Column(
      children: [
        LinearProgressIndicator(value: (_i + (answered ? 1 : 0)) / total, minHeight: 4, backgroundColor: Colors.white12, color: _gold),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Text('Question ${_i + 1} / $total', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: saved ? 'Saved' : 'Save for later',
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? _gold : Colors.white54),
                  onPressed: _toggleSave,
                ),
              ]),
              if (passage.isNotEmpty || passageImg.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (passage.isNotEmpty) Text(passage, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                      if (passageImg.isNotEmpty) Padding(padding: EdgeInsets.only(top: passage.isNotEmpty ? 8 : 0), child: DiImage(url: passageImg)),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)),
                child: Text(mockText(q, _hindi), style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              for (var oi = 0; oi < opts.length; oi++) _option(oi, opts[oi], q.correctIndex),
              if (answered && explanation.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (answered && !_finishing) ? _next : null,
              child: _finishing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_i == total - 1 ? 'Finish' : 'Next'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _option(int oi, String text, int correct) {
    final answered = _picked != null;
    final isCorrect = oi == correct;
    final isPicked = oi == _picked;
    var border = Colors.white24;
    var fill = Colors.transparent;
    var textColor = Colors.white;
    var mark = '';
    if (answered && isCorrect) {
      border = Colors.greenAccent;
      fill = const Color(0x2269F0AE);
      textColor = Colors.greenAccent;
      mark = '  ✓';
    } else if (answered && isPicked) {
      border = Colors.redAccent;
      fill = const Color(0x22FF5252);
      textColor = Colors.redAccent;
      mark = '  ✗';
    } else if (answered) {
      textColor = Colors.white54;
    }
    return GestureDetector(
      onTap: () => _pick(oi),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
        child: Text('${String.fromCharCode(65 + oi)}. $text$mark', style: TextStyle(color: textColor, fontSize: 14, height: 1.3)),
      ),
    );
  }

  Widget _resultView() {
    final total = widget.questions.length;
    var correct = 0;
    for (var i = 0; i < total; i++) {
      if (_answers[i] != null && _answers[i] == widget.questions[i].correctIndex) correct++;
    }
    final pct = total == 0 ? 0 : correct * 100 / total;
    final String msg;
    if (pct >= 80) {
      msg = 'Shandaar! 🔥 / शानदार!';
    } else if (pct >= 50) {
      msg = 'Accha hai, thoda aur! 💪 / अच्छा है, थोड़ा और!';
    } else {
      msg = 'Koi baat nahi, roz practice karo 🚀 / रोज़ अभ्यास करो';
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('$correct / $total', style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 40)),
              const Text('Sahi jawab', style: TextStyle(color: Color(0xFF101D57), fontSize: 13)),
              const SizedBox(height: 10),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: _navy, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Galat sawal apne aap "Mistake Notebook" me chale gaye hain. / गलत सवाल अपने आप Mistake Notebook में चले गए हैं।',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 18),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
