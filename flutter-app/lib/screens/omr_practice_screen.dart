import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../services/score_journal_store.dart';

// =============================================================================
//  OMR Practice - koi bhi paper (PDF / kitab / mock) hal karte hue yahan OMR jaisi
//  sheet me answer bharo, timer ke saath. Khatam hone par answer key (A B C D ...)
//  daalkar score, galat sawal aur accuracy dekho, aur Score Journal me save karo.
//  Sab kuch phone par - Firestore ko 0 reads / 0 writes.
// =============================================================================

enum _Stage { setup, test, result }

/// Marking pattern ka preset. Apni exam ka pattern notification me zaroor check karein.
class _Scheme {
  final String en;
  final String hi;
  final String mark;
  final String neg;
  final int opts;
  const _Scheme(this.en, this.hi, this.mark, this.neg, this.opts);
}

const List<_Scheme> _schemes = [
  _Scheme('SSC', 'एसएससी', '2', '0.5', 4),
  _Scheme('Banking', 'बैंकिंग', '1', '0.25', 5),
  _Scheme('Railway', 'रेलवे', '1', '1/3', 4),
  _Scheme('No negative', 'नेगेटिव नहीं', '1', '0', 4),
];

class _Eval {
  final int correct;
  final int wrong;
  final int blank;
  final double score;
  final List<int> wrongQs; // 0-based sawal number
  const _Eval(this.correct, this.wrong, this.blank, this.score, this.wrongQs);
}

class OmrPracticeScreen extends StatefulWidget {
  const OmrPracticeScreen({super.key});

  @override
  State<OmrPracticeScreen> createState() => _OmrPracticeScreenState();
}

class _OmrPracticeScreenState extends State<OmrPracticeScreen> {
  _Stage _stage = _Stage.setup;

  // ---- setup ----
  int _scheme = 0; // -1 = apne haath se badla
  int _opts = 4;
  final TextEditingController _qCtl = TextEditingController(text: '50');
  final TextEditingController _tCtl = TextEditingController(text: '45');
  final TextEditingController _mCtl = TextEditingController(text: '2');
  final TextEditingController _nCtl = TextEditingController(text: '0.5');
  String? _setupError;

  // ---- test ----
  int _total = 0;
  int _optCount = 4;
  double _mark = 1;
  double _neg = 0;
  int _limitSec = 0;
  int _remain = 0;
  DateTime _endAt = DateTime.now();
  List<int> _ans = <int>[]; // -1 = khali, 0 = A, 1 = B ...
  Timer? _timer;

  // ---- result ----
  int _usedSec = 0;
  final TextEditingController _keyCtl = TextEditingController();
  List<int>? _key;
  String? _keyError;
  bool _saved = false;

  @override
  void dispose() {
    _timer?.cancel();
    _qCtl.dispose();
    _tCtl.dispose();
    _mCtl.dispose();
    _nCtl.dispose();
    _keyCtl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  static double? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    if (t.contains('/')) {
      final p = t.split('/');
      if (p.length != 2) return null;
      final a = double.tryParse(p[0].trim());
      final b = double.tryParse(p[1].trim());
      if (a == null || b == null || b == 0) return null;
      return a / b;
    }
    return double.tryParse(t);
  }

  static String _fmtNum(double v) {
    if (v.isNaN || v.isInfinite) return '--';
    final r = (v * 100).round() / 100;
    if (r == r.roundToDouble()) return r.toStringAsFixed(0);
    var s = r.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }

  static String _fmtTime(int sec) {
    final s = sec < 0 ? 0 : sec;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final r = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final rr = r.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$rr' : '$mm:$rr';
  }

  static String _letter(int o) => String.fromCharCode(65 + o);

  int get _answered => _ans.where((a) => a >= 0).length;

  void _pickScheme(int i) {
    final s = _schemes[i];
    setState(() {
      _scheme = i;
      _opts = s.opts;
      _mCtl.text = s.mark;
      _nCtl.text = s.neg;
      _setupError = null;
    });
  }

  // -------------------------------------------------------------------- flow

  void _start() {
    final q = int.tryParse(_qCtl.text.trim());
    final t = int.tryParse(_tCtl.text.trim());
    final m = _parse(_mCtl.text);
    final n = _parse(_nCtl.text);
    if (q == null || q < 1 || q > 200) {
      setState(() => _setupError = 'Questions must be between 1 and 200.\nप्रश्न 1 से 200 के बीच होने चाहिए।');
      return;
    }
    if (t == null || t < 1 || t > 300) {
      setState(() => _setupError = 'Time must be between 1 and 300 minutes.\nसमय 1 से 300 मिनट के बीच होना चाहिए।');
      return;
    }
    if (m == null || m <= 0 || n == null || n < 0) {
      setState(() => _setupError = 'Please check the marks (negative can be like 0.25 or 1/3).\nकृपया अंक जाँचें (नेगेटिव 0.25 या 1/3 जैसा हो सकता है)।');
      return;
    }
    FocusScope.of(context).unfocus();
    _timer?.cancel();
    setState(() {
      _setupError = null;
      _total = q;
      _optCount = _opts;
      _mark = m;
      _neg = n;
      _limitSec = t * 60;
      _remain = t * 60;
      _endAt = DateTime.now().add(Duration(seconds: t * 60));
      _ans = List<int>.filled(q, -1);
      _key = null;
      _keyError = null;
      _saved = false;
      _keyCtl.clear();
      _stage = _Stage.test;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  // Samay dil se (deadline se) nikalte hain, taaki phone lock / app background
  // hone par bhi sahi rahe.
  void _tick() {
    if (!mounted) return;
    final ms = _endAt.difference(DateTime.now()).inMilliseconds;
    final left = ms <= 0 ? 0 : (ms / 1000).ceil();
    if (left <= 0) {
      _finish(auto: true);
      return;
    }
    if (left != _remain) setState(() => _remain = left);
  }

  void _finish({bool auto = false}) {
    _timer?.cancel();
    final ms = _endAt.difference(DateTime.now()).inMilliseconds;
    final left = ms <= 0 ? 0 : (ms / 1000).ceil();
    setState(() {
      _remain = left;
      _usedSec = auto ? _limitSec : (_limitSec - left).clamp(0, _limitSec).toInt();
      _stage = _Stage.result;
    });
    if (auto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time's up! Test submitted.\nसमय समाप्त! टेस्ट जमा हो गया।")),
        );
      });
    }
  }

  Future<void> _confirmSubmit() async {
    final left = _ans.length - _answered;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit test? / टेस्ट जमा करें?'),
        content: Text(left == 0 ? 'All questions are marked.\nसभी प्रश्न भरे हैं।' : '$left questions are still blank.\n$left प्रश्न अभी खाली हैं।'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back / वापस')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit / जमा करें')),
        ],
      ),
    );
    if (ok == true && mounted) _finish();
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the test? / टेस्ट छोड़ें?'),
        content: const Text('Your answers will be lost.\nआपके उत्तर मिट जाएँगे।'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay / रुकें')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Leave / छोड़ें')),
        ],
      ),
    );
    if (ok == true && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop();
    }
  }

  void _newTest() {
    _timer?.cancel();
    setState(() {
      _stage = _Stage.setup;
      _key = null;
      _keyError = null;
    });
  }

  // ------------------------------------------------------------ answer key

  // Sirf A.. (options ke hisaab se) akshar liye jaate hain, baaki (number, '-', space) chhod diye.
  List<int> _parseKey(String raw) {
    final out = <int>[];
    for (final unit in raw.toUpperCase().codeUnits) {
      final k = unit - 65;
      if (k >= 0 && k < _optCount) out.add(k);
    }
    return out;
  }

  void _check() {
    FocusScope.of(context).unfocus();
    final k = _parseKey(_keyCtl.text);
    if (k.length != _total) {
      setState(() {
        _key = null;
        _keyError = 'Found ${k.length} answers but the test has $_total questions. Type only the letters in question order.\n${k.length} उत्तर मिले, पर टेस्ट में $_total प्रश्न हैं। सिर्फ़ अक्षर प्रश्न-क्रम में लिखें।';
      });
      return;
    }
    setState(() {
      _key = k;
      _keyError = null;
    });
  }

  _Eval _eval(List<int> key) {
    var c = 0;
    var w = 0;
    var b = 0;
    final wrongQs = <int>[];
    for (var i = 0; i < _total; i++) {
      final a = _ans[i];
      if (a < 0) {
        b++;
      } else if (a == key[i]) {
        c++;
      } else {
        w++;
        wrongQs.add(i);
      }
    }
    return _Eval(c, w, b, c * _mark - w * _neg, wrongQs);
  }

  Future<void> _saveToJournal(_Eval e) async {
    final ok = await ScoreJournalStore.add(
      ScoreEntry(
        id: ScoreJournalStore.newId(),
        name: 'OMR Practice - $_total questions',
        score: e.score,
        total: _total * _mark,
        ms: DateTime.now().millisecondsSinceEpoch,
        note: '${e.correct} correct, ${e.wrong} wrong, ${e.blank} not attempted',
      ),
    );
    if (!mounted) return;
    if (ok) setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Saved in Score Journal. / स्कोर जर्नल में सेव हो गया।' : 'Could not save. Try again. / सेव नहीं हो सका, दोबारा कोशिश करें।')),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.setup:
        return _setupView();
      case _Stage.test:
        return _testView();
      case _Stage.result:
        return _resultView();
    }
  }

  // -------------------------------------------------------------- setup view

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppC.gold : AppC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppC.gold : AppC.line),
        ),
        child: Text(label, style: TextStyle(color: on ? AppC.onGold : AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String hint = '', bool text = false, VoidCallback? onEdited}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        onChanged: (_) {
          if (onEdited != null) onEdited();
        },
        keyboardType: text ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AppC.text, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppC.text70, fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: AppC.text38, fontSize: 12.5),
          filled: true,
          fillColor: AppC.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(t, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
    );
  }

  Widget _setupView() {
    return Scaffold(
      appBar: AppBar(title: const Text('OMR Practice / OMR अभ्यास', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Solve any paper (PDF, book or mock) and mark your answers here on an OMR-style sheet with a timer. Check with the answer key at the end.\nकोई भी पेपर (PDF, किताब या मॉक) हल करते हुए यहाँ OMR जैसी शीट पर टाइमर के साथ उत्तर भरें। अंत में आंसर की से जाँचें।',
              style: TextStyle(color: AppC.text, fontSize: 12.5, height: 1.45),
            ),
          ),
          _sectionTitle('Exam pattern / परीक्षा पैटर्न'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _schemes.length; i++) _chip('${_schemes[i].en} / ${_schemes[i].hi}', _scheme == i, () => _pickScheme(i)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Presets only fill the boxes below - edit them to match your own paper.\nप्रीसेट सिर्फ़ नीचे के खाने भरते हैं - अपने पेपर के हिसाब से बदलें।',
            style: TextStyle(color: AppC.text60, fontSize: 11.5, height: 1.4),
          ),
          _sectionTitle('Test settings / टेस्ट सेटिंग'),
          _field('Number of questions / प्रश्नों की संख्या', _qCtl, hint: '1 - 200'),
          _field('Time in minutes / समय (मिनट)', _tCtl, hint: 'e.g. 45'),
          _field('Marks per correct answer / सही उत्तर पर अंक', _mCtl, hint: 'e.g. 2', onEdited: () => setState(() => _scheme = -1)),
          _field('Negative marks per wrong answer / गलत पर नेगेटिव', _nCtl, hint: 'e.g. 0.25 or 1/3', text: true, onEdited: () => setState(() => _scheme = -1)),
          _sectionTitle('Options per question / प्रति प्रश्न विकल्प'),
          Wrap(
            spacing: 8,
            children: [
              _chip('4 options (A-D)', _opts == 4, () => setState(() => _opts = 4)),
              _chip('5 options (A-E)', _opts == 5, () => setState(() => _opts = 5)),
            ],
          ),
          if (_setupError != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(_setupError!, style: TextStyle(color: AppC.red, fontSize: 12.5, height: 1.4)),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start test / टेस्ट शुरू करें'),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- test view

  Widget _bubble(int q, int o) {
    final on = _ans[q] == o;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _ans[q] = on ? -1 : o);
        },
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppC.gold : Colors.transparent,
              border: Border.all(color: on ? AppC.gold : AppC.text38, width: 1.5),
            ),
            child: Text(_letter(o), style: TextStyle(color: on ? AppC.onGold : AppC.text70, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
    );
  }

  Widget _qRow(int q) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: q.isEven ? AppC.card : Colors.transparent,
        border: Border(bottom: BorderSide(color: AppC.line, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${q + 1}', style: TextStyle(color: _ans[q] >= 0 ? AppC.accent : AppC.text54, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          for (var o = 0; o < _optCount; o++) _bubble(q, o),
        ],
      ),
    );
  }

  Widget _testView() {
    final low = _remain <= 60;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Leave / छोड़ें', onPressed: _confirmExit),
          title: Row(
            children: [
              Icon(Icons.timer_outlined, size: 20, color: low ? AppC.red : AppC.gold),
              const SizedBox(width: 6),
              Text(_fmtTime(_remain), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: low ? AppC.red : AppC.gold)),
            ],
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text('$_answered / $_total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppC.card2,
              child: Row(
                children: [
                  const SizedBox(width: 34),
                  for (var o = 0; o < _optCount; o++)
                    Expanded(
                      child: Center(child: Text(_letter(o), style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14))),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _total,
                itemExtent: 54,
                itemBuilder: (context, q) => _qRow(q),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: _confirmSubmit, child: const Text('Submit / जमा करें')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- result view

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppC.onGold, fontSize: 12.5, fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(color: AppC.onGold, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _resultView() {
    final key = _key;
    final e = key == null ? null : _eval(key);
    final attempted = _answered;
    final maxMarks = _total * _mark;
    return Scaffold(
      appBar: AppBar(title: const Text('Result / नतीजा', style: TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e != null) ...[
                  const Text('Your score / आपका स्कोर', style: TextStyle(color: AppC.onGold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text('${_fmtNum(e.score)} / ${_fmtNum(maxMarks)}', style: const TextStyle(color: AppC.onGold, fontSize: 30, fontWeight: FontWeight.bold)),
                  _statRow('Correct / सही', '${e.correct}'),
                  _statRow('Wrong / गलत', '${e.wrong}'),
                  _statRow('Not attempted / छोड़े', '${e.blank}'),
                  _statRow('Accuracy / सटीकता', e.correct + e.wrong == 0 ? '--' : '${_fmtNum(e.correct / (e.correct + e.wrong) * 100)}%'),
                  _statRow('Percentage / प्रतिशत', maxMarks <= 0 ? '--' : '${_fmtNum(e.score / maxMarks * 100)}%'),
                ] else ...[
                  const Text('Test submitted / टेस्ट जमा', style: TextStyle(color: AppC.onGold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text('$attempted / $_total attempted', style: const TextStyle(color: AppC.onGold, fontSize: 26, fontWeight: FontWeight.bold)),
                  _statRow('Not attempted / छोड़े', '${_total - attempted}'),
                ],
                _statRow('Time used / लगा समय', _fmtTime(_usedSec)),
              ],
            ),
          ),
          if (e == null) ...[
            _sectionTitle('Check with answer key / आंसर की से जाँचें'),
            Text(
              'Type or paste the key letters in question order, for example: A C B D D A ...\nआंसर की के अक्षर प्रश्न-क्रम में लिखें या पेस्ट करें, जैसे: A C B D D A ...',
              style: TextStyle(color: AppC.text60, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _keyCtl,
              maxLines: 4,
              minLines: 3,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: AppC.text, fontSize: 15, letterSpacing: 1.2),
              decoration: InputDecoration(
                hintText: 'A C B D ...',
                hintStyle: TextStyle(color: AppC.text38),
                filled: true,
                fillColor: AppC.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (_keyError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_keyError!, style: TextStyle(color: AppC.red, fontSize: 12, height: 1.4)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _check, child: const Text('Check answers / उत्तर जाँचें')),
            ),
          ] else ...[
            if (e.wrongQs.isNotEmpty) ...[
              _sectionTitle('Wrong answers / गलत उत्तर  (yours → key)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in e.wrongQs)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppC.redWash, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.red)),
                      child: Text('Q${q + 1}: ${_letter(_ans[q])} → ${_letter(key![q])}', style: TextStyle(color: AppC.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saved ? null : () => _saveToJournal(e),
                icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(_saved ? 'Saved / सेव हो गया' : 'Save to Score Journal / स्कोर जर्नल में सेव करें'),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => setState(() {
                  _key = null;
                  _keyError = null;
                }),
                child: const Text('Change answer key / आंसर की बदलें'),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _newTest,
              icon: const Icon(Icons.refresh),
              label: const Text('New test / नया टेस्ट'),
            ),
          ),
        ],
      ),
    );
  }
}
