import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../services/share_service.dart';
import '../services/speed_math_generator.dart';
import '../services/speed_math_store.dart';
import '../services/study_store.dart';
import 'ready_reckoner_screen.dart';

/// Speed Maths Arena: squares, cubes, tables, roots, fraction<->%, percentage,
/// quick calc, BODMAS aur number series ke tez drills.
/// Sawal phone par hi bante hain, score phone me save hota hai -
/// Firestore ko 0 reads / 0 writes.
class SpeedMathScreen extends StatefulWidget {
  const SpeedMathScreen({super.key});

  @override
  State<SpeedMathScreen> createState() => _SpeedMathScreenState();
}

class _SpeedMathScreenState extends State<SpeedMathScreen> {
  MathDrill _drill = MathDrill.mix;
  bool _rapid = true;
  Map<String, SpeedBest> _bests = const <String, SpeedBest>{};
  int _today = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await SpeedMathStore.allBests();
      final t = await SpeedMathStore.roundsOn(StudyStore.today());
      final tot = await SpeedMathStore.totalRounds();
      if (!mounted) return;
      setState(() {
        _bests = b;
        _today = t;
        _total = tot;
      });
    } catch (_) {
      // score nahi dikha to menu phir bhi chalta hai
    }
  }

  String get _mode => _rapid ? SpeedMathStore.modeRapid : SpeedMathStore.modeQuestions;

  String _bestText(DrillInfo d) {
    final b = _bests['${d.id}_$_mode'];
    if (b == null) return 'Best: —';
    if (_rapid) return 'Best: ${b.correct}';
    return 'Best: ${b.correct}/${SpeedMathStore.questionCount} · ${b.seconds}s';
  }

  Future<void> _start() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpeedMathPlayScreen(drill: _drill, rapid: _rapid)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speed Maths Arena')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 10),
          // Practice se pehle yaad karne ke liye chart (squares, cubes, tables ...).
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadyReckonerScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppC.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppC.accent.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Text('🧮', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ready Reckoner chart', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text('Learn squares, cubes, tables, roots, fraction % first\nपहले वर्ग, घन, पहाड़े, मूल, भिन्न % याद करें',
                            style: TextStyle(color: AppC.text70, fontSize: 11.5, height: 1.3)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppC.accent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _modeTile(true, '⏱️', 'Rapid Fire', '60 seconds / 60 सेकंड'),
              const SizedBox(width: 10),
              _modeTile(false, '🎯', '20 Questions', 'Beat the clock / समय से जीतो'),
            ],
          ),
          const SizedBox(height: 16),
          Text('Choose a drill / ड्रिल चुनें', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _drillGrid(),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _start,
            child: Text('Start / शुरू करें  •  ${drillInfo(_drill).en}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          Text(
            'Wrong answer = 2 second penalty. Questions are made fresh every time.\nगलत जवाब पर 2 सेकंड की सज़ा। हर बार नए सवाल बनते हैं।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Train your calculation speed', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14.5)),
                Text('गणना की रफ़्तार बढ़ाओ', style: TextStyle(color: AppC.text70, fontSize: 12.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Today / आज: $_today', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 2),
              Text('Total / कुल: $_total', style: TextStyle(color: AppC.text54, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeTile(bool rapid, String emoji, String title, String sub) {
    final sel = _rapid == rapid;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rapid = rapid),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? AppC.goldWash2 : AppC.card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppC.gold : AppC.line, width: sel ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Text('$emoji $title', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 3),
              Text(sub, textAlign: TextAlign.center, style: TextStyle(color: AppC.text60, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drillGrid() {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in kDrills) SizedBox(width: w, child: _drillTile(d)),
          ],
        );
      },
    );
  }

  Widget _drillTile(DrillInfo d) {
    final sel = _drill == d.drill;
    return GestureDetector(
      onTap: () => setState(() => _drill = d.drill),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? AppC.goldWash2 : AppC.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppC.gold : AppC.line, width: sel ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(d.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(d.en, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(d.hi, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text70, fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(d.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.muted, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text(_bestText(d), style: TextStyle(color: AppC.accent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  Khel ki screen: 3-2-1 countdown -> sawal -> natija.
// =============================================================================

enum _Phase { countdown, playing, result }

class SpeedMathPlayScreen extends StatefulWidget {
  final MathDrill drill;
  final bool rapid; // true = 60 second Rapid Fire, false = 20 sawal
  const SpeedMathPlayScreen({super.key, required this.drill, required this.rapid});

  @override
  State<SpeedMathPlayScreen> createState() => _SpeedMathPlayScreenState();
}

class _SpeedMathPlayScreenState extends State<SpeedMathPlayScreen> {
  static const int _penaltyPerWrongMs = 2000;

  final Random _rnd = Random();
  _Phase _phase = _Phase.countdown;
  int _count = 3;
  Timer? _timer;
  late SpeedQuestion _q;
  int _correct = 0;
  int _wrong = 0;
  int? _picked;
  bool _locked = false;
  bool _finishing = false;
  int _elapsedMs = 0;
  DateTime _startedAt = DateTime.now();
  bool _newBest = false;
  int _finalSeconds = 0;

  DrillInfo get _info => drillInfo(widget.drill);
  int get _answered => _correct + _wrong;
  int get _limitMs => SpeedMathStore.rapidSeconds * 1000;
  int get _penaltyMs => _wrong * _penaltyPerWrongMs;

  @override
  void initState() {
    super.initState();
    _q = SpeedMathGenerator.next(widget.drill, _rnd);
    _beginCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetRound() {
    _phase = _Phase.countdown;
    _count = 3;
    _correct = 0;
    _wrong = 0;
    _picked = null;
    _locked = false;
    _finishing = false;
    _elapsedMs = 0;
    _newBest = false;
    _q = SpeedMathGenerator.next(widget.drill, _rnd);
  }

  void _beginCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_count > 1) {
        setState(() => _count--);
      } else {
        t.cancel();
        _beginPlay();
      }
    });
  }

  void _beginPlay() {
    _startedAt = DateTime.now();
    setState(() {
      _phase = _Phase.playing;
      _elapsedMs = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final ms = DateTime.now().difference(_startedAt).inMilliseconds;
      if (widget.rapid && ms + _penaltyMs >= _limitMs) {
        t.cancel();
        setState(() => _elapsedMs = max(0, _limitMs - _penaltyMs));
        _finish();
        return;
      }
      setState(() => _elapsedMs = ms);
    });
  }

  void _pick(int i) {
    if (_phase != _Phase.playing || _locked || _finishing) return;
    final ok = i == _q.correct;
    HapticFeedback.selectionClick();
    setState(() {
      _picked = i;
      _locked = true;
      if (ok) {
        _correct++;
      } else {
        _wrong++;
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (!mounted || _phase != _Phase.playing || _finishing) return;
      if (!widget.rapid && _answered >= SpeedMathStore.questionCount) {
        _finish();
        return;
      }
      setState(() {
        _q = SpeedMathGenerator.next(widget.drill, _rnd);
        _picked = null;
        _locked = false;
      });
    });
  }

  Future<void> _finish() async {
    if (_finishing || _phase == _Phase.result) return;
    _finishing = true;
    _timer?.cancel();
    final int secs;
    if (widget.rapid) {
      secs = SpeedMathStore.rapidSeconds;
    } else {
      final ms = DateTime.now().difference(_startedAt).inMilliseconds + _penaltyMs;
      secs = max(1, (ms / 1000).round());
    }
    final best = await SpeedMathStore.recordRound(
      drillId: _info.id,
      mode: widget.rapid ? SpeedMathStore.modeRapid : SpeedMathStore.modeQuestions,
      correct: _correct,
      answered: _answered,
      seconds: secs,
    );
    if (!mounted) return;
    setState(() {
      _finalSeconds = secs;
      _newBest = best;
      _picked = null;
      _locked = false;
      _phase = _Phase.result;
    });
  }

  void _playAgain() {
    setState(_resetRound);
    _beginCountdown();
  }

  int get _accuracy => _answered == 0 ? 0 : (_correct * 100 / _answered).round();

  void _share() {
    final info = _info;
    final line = widget.rapid
        ? '⚡ ${info.en}: $_correct correct in 60 seconds ($_accuracy% accuracy). Can you beat me?\n'
            'मैंने 60 सेकंड में $_correct सही किए। क्या आप मुझे हरा सकते हैं?'
        : '⚡ ${info.en}: $_correct/${SpeedMathStore.questionCount} correct in ${_finalSeconds}s ($_accuracy% accuracy). Can you beat me?\n'
            'मैंने ${SpeedMathStore.questionCount} में से $_correct सवाल ${_finalSeconds} सेकंड में सही किए। क्या आप मुझे हरा सकते हैं?';
    ShareService.custom(context, '⚡ Speed Maths Arena', line);
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_phase) {
      _Phase.countdown => _countdownView(),
      _Phase.playing => _playView(),
      _Phase.result => _resultView(),
    };
    return Scaffold(
      appBar: AppBar(title: Text('${_info.emoji} ${_info.en}')),
      body: SafeArea(child: body),
    );
  }

  // ------------------------------------------------------------ countdown

  Widget _countdownView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Get ready / तैयार हो जाओ', style: TextStyle(color: AppC.text70, fontSize: 16)),
          const SizedBox(height: 10),
          Text('$_count', style: TextStyle(color: AppC.accent, fontSize: 96, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            widget.rapid ? 'Solve as many as you can in 60 seconds\n60 सेकंड में जितने हो सकें हल करो' : 'Solve 20 questions as fast as you can\n20 सवाल जितनी तेज़ी से हो सके हल करो',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text54, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- playing

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _playView() {
    final rapid = widget.rapid;
    final eff = _elapsedMs + _penaltyMs;
    final remain = max(0, _limitMs - eff);
    final double ratio = rapid ? remain / _limitMs : _answered / SpeedMathStore.questionCount;
    final timeText = rapid ? '${(remain / 1000).ceil()}s' : '${(eff / 1000).toStringAsFixed(1)}s';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _chip('✓ $_correct', AppC.green),
              const SizedBox(width: 8),
              _chip('✗ $_wrong', AppC.red),
              const Spacer(),
              Text(timeText, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.w800, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: AppC.line,
              color: AppC.gold,
            ),
          ),
          if (!rapid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Q ${min(_answered + 1, SpeedMathStore.questionCount)} / ${SpeedMathStore.questionCount}', style: TextStyle(color: AppC.text54, fontSize: 12)),
            ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_q.text, textAlign: TextAlign.center, style: TextStyle(color: AppC.text, fontSize: 46, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
          SizedBox(height: 74, child: Row(children: [_optionCell(0), _optionCell(1)])),
          SizedBox(height: 74, child: Row(children: [_optionCell(2), _optionCell(3)])),
          const SizedBox(height: 8),
          Text('Wrong answer = 2s penalty / गलत जवाब = 2 सेकंड की सज़ा', style: TextStyle(color: AppC.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _optionCell(int i) {
    return Expanded(
      child: Padding(padding: const EdgeInsets.all(5), child: _optionBox(i)),
    );
  }

  Widget _optionBox(int i) {
    var bg = AppC.card2;
    var border = AppC.line;
    if (_picked != null) {
      if (i == _q.correct) {
        bg = AppC.greenWash;
        border = AppC.green;
      } else if (i == _picked) {
        bg = AppC.redWash;
        border = AppC.red;
      }
    }
    return GestureDetector(
      onTap: () => _pick(i),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_q.options[i], style: TextStyle(color: AppC.text, fontSize: 24, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- result

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 19)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppC.text54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _resultView() {
    final rapid = widget.rapid;
    final avg = _answered == 0 ? 0.0 : _finalSeconds / _answered;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 8),
        Center(child: Text(_newBest ? '🏆' : '⚡', style: const TextStyle(fontSize: 54))),
        const SizedBox(height: 6),
        if (_newBest)
          Center(
            child: Text('New best! / नया रिकॉर्ड!', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.w800, fontSize: 17)),
          ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            rapid ? '$_correct' : '$_correct / ${SpeedMathStore.questionCount}',
            style: TextStyle(color: AppC.text, fontSize: 60, fontWeight: FontWeight.w800),
          ),
        ),
        Center(
          child: Text(
            rapid ? 'correct in 60 sec / 60 सेकंड में सही' : 'correct in ${_finalSeconds}s (with penalties) / ${_finalSeconds} सेकंड में (सज़ा सहित)',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text70, fontSize: 13),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _statTile('Accuracy\nसटीकता', '$_accuracy%', AppC.green),
            const SizedBox(width: 8),
            _statTile('Wrong\nगलत', '$_wrong', AppC.red),
            const SizedBox(width: 8),
            _statTile('Sec / question\nसेकंड / सवाल', avg.toStringAsFixed(1), AppC.accent),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _playAgain,
          child: const Text('Play again / फिर खेलें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _share,
          icon: Icon(Icons.share_outlined, color: AppC.text, size: 18),
          label: Text('Share score / स्कोर शेयर करें', style: TextStyle(color: AppC.text)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: AppC.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Back to drills / ड्रिल पर वापस', style: TextStyle(color: AppC.text70)),
        ),
      ],
    );
  }
}
