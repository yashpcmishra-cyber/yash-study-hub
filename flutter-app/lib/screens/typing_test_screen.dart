import 'dart:async';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/typing_data.dart';
import '../services/share_service.dart';
import '../services/typing_store.dart';

enum _TypingPhase { setup, typing, result }

/// Typing Speed Test (English / हिंदी). Passage dekhkar typing karo - 1, 2, 3 ya
/// 5 minute ka timer, net WPM aur accuracy. Passages app me bundled hain
/// (internet nahi chahiye). Best score / history sirf phone me - Firestore 0.
class TypingTestScreen extends StatefulWidget {
  const TypingTestScreen({super.key});

  @override
  State<TypingTestScreen> createState() => _TypingTestScreenState();
}

class _TypingTestScreenState extends State<TypingTestScreen> {
  _TypingPhase _phase = _TypingPhase.setup;
  String _lang = 'en';
  int _minutes = 1;

  // setup screen data
  int _bestEn = 0;
  int _bestHi = 0;
  int _tests = 0;
  List<TypingRecord> _hist = const <TypingRecord>[];

  // test state
  List<String> _order = <String>[];
  int _pi = 0;
  String _target = '';
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _timer;
  int _remain = 0;
  bool _started = false;
  int _doneCorrect = 0;
  int _doneTyped = 0;

  // result
  int _wpm = 0;
  int _acc = 0;
  int _typed = 0;
  int _correct = 0;
  TypingSaveResult? _saved;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadSetup() async {
    final en = await TypingStore.best('en');
    final hi = await TypingStore.best('hi');
    final h = await TypingStore.history();
    final t = await TypingStore.totalTests();
    if (!mounted) return;
    setState(() {
      _bestEn = en;
      _bestHi = hi;
      _hist = h;
      _tests = t;
    });
  }

  // ------------------------------------------------------------ test logic

  static int _matches(String typed, String target) {
    final n = typed.length < target.length ? typed.length : target.length;
    var c = 0;
    for (var i = 0; i < n; i++) {
      if (typed.codeUnitAt(i) == target.codeUnitAt(i)) c++;
    }
    return c;
  }

  void _start() {
    final src = _lang == 'hi' ? kTypingHindi : kTypingEnglish;
    _order = List<String>.from(src)..shuffle();
    _pi = 0;
    _target = _order[0];
    _ctl.clear();
    _doneCorrect = 0;
    _doneTyped = 0;
    _started = false;
    _remain = _minutes * 60;
    _timer?.cancel();
    setState(() => _phase = _TypingPhase.typing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onChanged(String v) {
    if (_phase != _TypingPhase.typing) return;
    if (!_started && v.isNotEmpty) {
      _started = true;
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
    if (v.length >= _target.length) {
      // Passage poora hua -> hisaab jodo, agla passage lao.
      final done = v.substring(0, _target.length);
      _doneTyped += _target.length;
      _doneCorrect += _matches(done, _target);
      _pi = (_pi + 1) % _order.length;
      _target = _order[_pi];
      _ctl.clear();
    }
    setState(() {});
  }

  void _tick(Timer t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    _remain--;
    if (_remain <= 0) {
      _finish();
    } else {
      setState(() {});
    }
  }

  int get _liveTyped => _doneTyped + (_ctl.text.length > _target.length ? _target.length : _ctl.text.length);
  int get _liveCorrect => _doneCorrect + _matches(_ctl.text, _target);

  Future<void> _finish() async {
    if (_phase != _TypingPhase.typing) return;
    _timer?.cancel();
    final typed = _liveTyped;
    final correct = _liveCorrect;
    final wpm = ((correct / 5) / _minutes).round();
    final acc = typed == 0 ? 0 : (correct * 100 / typed).round();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _typed = typed;
      _correct = correct;
      _wpm = wpm;
      _acc = acc;
      _saved = null;
      _phase = _TypingPhase.result;
    });
    final r = await TypingStore.record(lang: _lang, minutes: _minutes, wpm: wpm, accuracy: acc);
    if (!mounted) return;
    setState(() => _saved = r);
    _loadSetup();
  }

  void _backToSetup() {
    _timer?.cancel();
    _started = false;
    setState(() => _phase = _TypingPhase.setup);
  }

  Future<bool> _confirmQuit() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card2,
        title: Text('Quit the test? / टेस्ट छोड़ना है?', style: TextStyle(color: AppC.text, fontSize: 16)),
        content: Text('Your result will not be saved. / इस टेस्ट का नतीजा सेव नहीं होगा।', style: TextStyle(color: AppC.text70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Continue')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Quit', style: TextStyle(color: AppC.red))),
        ],
      ),
    );
    return r == true;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final inTest = _phase == _TypingPhase.typing && _started;
    return PopScope(
      canPop: !inTest,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final quit = await _confirmQuit();
        if (quit && mounted) {
          _timer?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Typing Test / टाइपिंग टेस्ट')),
        body: switch (_phase) {
          _TypingPhase.setup => _setupView(),
          _TypingPhase.typing => _typingView(),
          _TypingPhase.result => _resultView(),
        },
      ),
    );
  }

  Widget _choice(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppC.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppC.gold : AppC.text24),
        ),
        child: Text(label, style: TextStyle(color: active ? AppC.onGold : AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
      );

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  Widget _bestCard(String label, int wpm) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(wpm == 0 ? '--' : '$wpm', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 26)),
            Text('WPM', style: TextStyle(color: AppC.text54, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: AppC.text70, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _setupView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _sectionLabel('Language / भाषा'),
        Row(children: [
          _choice('English', _lang == 'en', () => setState(() => _lang = 'en')),
          const SizedBox(width: 10),
          _choice('हिंदी', _lang == 'hi', () => setState(() => _lang = 'hi')),
        ]),
        if (_lang == 'hi')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Turn on a Hindi keyboard (e.g. Gboard Hindi). / हिंदी कीबोर्ड चालू करें।', style: TextStyle(color: AppC.muted, fontSize: 11.5)),
          ),
        _sectionLabel('Duration / समय'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final m in const [1, 2, 3, 5]) _choice('$m min', _minutes == m, () => setState(() => _minutes = m)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.keyboard),
            label: const Text('Start test / टेस्ट शुरू करें'),
          ),
        ),
        const SizedBox(height: 6),
        Text('The timer starts when you type the first letter. / पहला अक्षर टाइप करते ही टाइमर शुरू होगा।', textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5)),
        _sectionLabel('Your best / आपका बेस्ट'),
        Row(children: [
          _bestCard('English', _bestEn),
          const SizedBox(width: 10),
          _bestCard('हिंदी', _bestHi),
        ]),
        const SizedBox(height: 6),
        Text('Best is saved only when accuracy is 80% or more. / बेस्ट तभी सेव होता है जब एक्यूरेसी 80% या ज़्यादा हो।', style: TextStyle(color: AppC.muted, fontSize: 11)),
        if (_hist.isNotEmpty) ...[
          _sectionLabel('Recent tests / पिछले टेस्ट  ($_tests)'),
          for (final r in _hist.take(6))
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.line)),
              child: Row(
                children: [
                  Text(r.lang == 'hi' ? 'हिं' : 'EN', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${r.wpm} WPM  •  ${r.accuracy}%  •  ${r.minutes} min', style: TextStyle(color: AppC.text, fontSize: 13))),
                  Text(_date(r.ms), style: TextStyle(color: AppC.text38, fontSize: 11)),
                ],
              ),
            ),
        ],
        _sectionLabel('Tips / सुझाव'),
        Text(
          '• Accuracy first, speed will follow.\n• Aim for 30+ WPM with 95%+ accuracy.\n• Do one test every day.\n\n'
          '• पहले एक्यूरेसी, स्पीड अपने आप बढ़ेगी।\n• 95%+ एक्यूरेसी के साथ 30+ WPM का लक्ष्य रखें।\n• रोज़ एक टेस्ट दें।',
          style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.45),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ typing view

  String _mmss(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  Widget _stat(String big, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(big, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: TextStyle(color: AppC.text54, fontSize: 10.5)),
        ],
      ),
    );
  }

  // 0 sahi, 1 galat, 2 aage ka, 3 abhi ka akshar (cursor)
  int _status(int i, String typed) {
    if (i < typed.length) return typed.codeUnitAt(i) == _target.codeUnitAt(i) ? 0 : 1;
    if (i == typed.length) return 3;
    return 2;
  }

  TextStyle _styleFor(int st) {
    switch (st) {
      case 0:
        return TextStyle(color: AppC.green);
      case 1:
        return TextStyle(color: AppC.red, backgroundColor: AppC.redWash);
      case 3:
        return TextStyle(color: AppC.text, backgroundColor: AppC.goldWash2, fontWeight: FontWeight.bold);
      default:
        return TextStyle(color: AppC.text70);
    }
  }

  Widget _passage() {
    final typed = _ctl.text.length > _target.length ? _ctl.text.substring(0, _target.length) : _ctl.text;
    final spans = <TextSpan>[];
    var i = 0;
    while (i < _target.length) {
      final st = _status(i, typed);
      var j = i + 1;
      if (st != 3) {
        while (j < _target.length && _status(j, typed) == st) {
          j++;
        }
      }
      spans.add(TextSpan(text: _target.substring(i, j), style: _styleFor(st)));
      i = j;
    }
    return RichText(
      text: TextSpan(style: TextStyle(fontSize: 17, height: 1.6, color: AppC.text70), children: spans),
    );
  }

  Widget _typingView() {
    final elapsed = _minutes * 60 - _remain;
    final live = (elapsed >= 5) ? (((_liveCorrect / 5) / (elapsed / 60))).round() : 0;
    final typed = _liveTyped;
    final acc = typed == 0 ? 100 : (_liveCorrect * 100 / typed).round();
    return Column(
      children: [
        LinearProgressIndicator(
          value: _minutes * 60 == 0 ? 0 : (elapsed / (_minutes * 60)).clamp(0.0, 1.0).toDouble(),
          minHeight: 4,
          backgroundColor: AppC.text12,
          color: AppC.accent,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            _stat(_mmss(_remain), 'Time left / समय'),
            _stat(_started ? '$live' : '--', 'WPM'),
            _stat('$acc%', 'Accuracy'),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
              child: _passage(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  focusNode: _focus,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 1,
                  maxLines: 2,
                  onChanged: _onChanged,
                  style: TextStyle(color: AppC.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Type here… / यहाँ टाइप करें…',
                    hintStyle: TextStyle(color: AppC.text38),
                    filled: true,
                    fillColor: AppC.card,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Finish now',
                icon: Icon(Icons.stop_circle_outlined, color: AppC.red, size: 30),
                onPressed: _started ? () => _finishEarly() : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Time khatam hone se pehle roka: WPM beete hue time ke hisaab se nikalta hai.
  Future<void> _finishEarly() async {
    if (_phase != _TypingPhase.typing) return;
    final elapsedSec = _minutes * 60 - _remain;
    if (elapsedSec < 10) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Type for at least 10 seconds. / कम से कम 10 सेकंड टाइप करें।'), duration: Duration(seconds: 2)));
      return;
    }
    _timer?.cancel();
    final typed = _liveTyped;
    final correct = _liveCorrect;
    final wpm = ((correct / 5) / (elapsedSec / 60)).round();
    final acc = typed == 0 ? 0 : (correct * 100 / typed).round();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _typed = typed;
      _correct = correct;
      _wpm = wpm;
      _acc = acc;
      _saved = null;
      _phase = _TypingPhase.result;
    });
    final r = await TypingStore.record(lang: _lang, minutes: _minutes, wpm: wpm, accuracy: acc);
    if (!mounted) return;
    setState(() => _saved = r);
    _loadSetup();
  }

  // ------------------------------------------------------------ result view

  String _message() {
    if (_acc < 80) return 'Slow down and focus on accuracy 🎯 / पहले एक्यूरेसी पर ध्यान दें';
    if (_wpm >= 40) return 'Excellent speed! 🔥 / शानदार स्पीड!';
    if (_wpm >= 30) return 'Very good! 💪 / बहुत बढ़िया!';
    if (_wpm >= 20) return 'Good, keep going 🚀 / अच्छा है, लगे रहिए';
    return 'Practice daily, you will improve 🌱 / रोज़ अभ्यास करें';
  }

  Widget _resultView() {
    final saved = _saved;
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
              Text('$_wpm', style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 52)),
              const Text('Words per minute / शब्द प्रति मिनट', style: TextStyle(color: AppC.onGold, fontSize: 13)),
              const SizedBox(height: 10),
              Text('Accuracy: $_acc%   •   $_correct / $_typed correct', textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Text(_message(), textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (saved != null && saved.newBest)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: AppC.greenWash, borderRadius: BorderRadius.circular(10)),
            child: Text('🏆 New personal best! / नया पर्सनल बेस्ट!', textAlign: TextAlign.center, style: TextStyle(color: AppC.green, fontWeight: FontWeight.bold)),
          ),
        if (saved != null && saved.xp > 0)
          Text('⭐ +${saved.xp} XP', textAlign: TextAlign.center, style: TextStyle(color: AppC.text70, fontSize: 13)),
        if (_acc < 80 && _wpm > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Best score counts only at 80%+ accuracy. / बेस्ट स्कोर 80%+ एक्यूरेसी पर ही गिना जाता है।', textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5)),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ShareService.custom(
            context,
            '⌨️ My typing speed: $_wpm WPM',
            'I typed at $_wpm WPM with $_acc% accuracy. Test your typing speed too!\nमैंने $_wpm WPM की स्पीड और $_acc% एक्यूरेसी से टाइप किया।',
          ),
          icon: const Icon(Icons.share),
          label: const Text('Share / शेयर करें'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppC.accent,
            side: BorderSide(color: AppC.accent),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _start, child: const Text('Try again / दोबारा')),
        const SizedBox(height: 6),
        TextButton(onPressed: _backToSetup, child: const Text('Change settings / सेटिंग बदलें')),
      ],
    );
  }
}
