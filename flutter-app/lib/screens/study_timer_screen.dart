import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../services/study_time_store.dart';
import '../services/study_timer_service.dart';

// =============================================================================
//  Study Timer (Pomodoro) - focus session chalao, break lo, din ka hisaab dekho.
//
//  Ye screen sirf dikhati hai. Timer StudyTimerService me chalta hai, isliye
//  back karke Mocks / PDFs / Quiz me jaane par bhi timer chalta rehta hai
//  (har screen par chhota floating pill dikhta hai: pause / stop).
//
//  * Focus ka har poora minute StudyTimeStore me jaata hai (1 XP / minute).
//    Break ka time count nahi hota.
//  * Subject-wise time aur daily time-goal sirf phone me ('ysh5_' keys -
//    Cloud Backup me apne aap shamil). Firestore ko 0 reads / 0 writes.
// =============================================================================

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  static const List<int> _focusOptions = [15, 25, 45, 60];
  static const List<int> _breakOptions = [5, 10];
  static const List<int> _goalOptions = [60, 120, 180, 240]; // minute
  static const List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final StudyTimerService _s = StudyTimerService.instance;

  List<DayStudy> _week = const <DayStudy>[];
  int _allSec = 0;
  int _sessions = 0;
  Map<String, int> _subj = <String, int>{};

  @override
  void initState() {
    super.initState();
    _s.addListener(_onTimer);
    StudyTimeStore.changes.addListener(_reload);
    // Build ke beech notify na ho, isliye thoda baad me.
    Future<void>.microtask(() => _s.setScreenOpen(true));
    _s.init(); // pehli baar ho to saved settings / chalta timer le aata hai
    _reload();
  }

  @override
  void dispose() {
    _s.removeListener(_onTimer);
    StudyTimeStore.changes.removeListener(_reload);
    // Timer band NAHI hota - sirf floating pill wapas dikhne lagta hai.
    Future<void>.microtask(() => _s.setScreenOpen(false));
    super.dispose();
  }

  void _onTimer() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    try {
      final week = await StudyTimeStore.last7();
      final all = await StudyTimeStore.totalSeconds();
      final sessions = await StudyTimeStore.totalSessions();
      final subj = await _s.subjectSecs();
      if (!mounted) return;
      setState(() {
        _week = week;
        _allSec = all;
        _sessions = sessions;
        _subj = subj;
      });
    } catch (_) {
      // purani values dikhti rahengi
    }
  }

  Future<void> _customMinutes() async {
    final ctrl = TextEditingController(text: '${_s.isBreak ? _s.breakMin : _s.focusMin}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card2,
        title: Text('Custom time / अपना समय', style: TextStyle(color: AppC.text, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 3,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: AppC.text),
          decoration: InputDecoration(
            labelText: 'Minutes (1–180) / मिनट',
            labelStyle: TextStyle(color: AppC.text60),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim()) ?? 0), child: const Text('Set')),
        ],
      ),
    );
    if (v == null) return;
    if (v < 1 || v > 180) {
      _toast('Enter 1 to 180 minutes. / 1 से 180 मिनट डालें।');
      return;
    }
    _s.setMinutes(v);
  }

  Future<void> _editGoal() async {
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppC.card2,
        title: Text('Daily study goal / रोज़ का पढ़ाई लक्ष्य', style: TextStyle(color: AppC.text, fontSize: 16)),
        children: [
          for (final n in _goalOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(n),
              child: Text(
                '${_hm(n * 60)} per day / प्रतिदिन${n == _s.goalMin ? '  ✓' : ''}',
                style: TextStyle(color: n == _s.goalMin ? AppC.accent : AppC.text, fontSize: 15),
              ),
            ),
        ],
      ),
    );
    if (v == null) return;
    _s.setGoal(v);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------- helpers

  static String _clock(int sec) {
    final s = sec < 0 ? 0 : sec;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  static String _hm(int seconds) => StudyTimeStore.fmt(seconds);

  List<String> _subjectInfo(String key) {
    for (final s in StudyTimerService.subjects) {
      if (s[1] == key) return s;
    }
    return StudyTimerService.subjects.last;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final todaySec = _week.isEmpty ? 0 : _week.last.seconds;
    return Scaffold(
        appBar: AppBar(title: const Text('Study Timer / स्टडी टाइमर')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _modeSwitch(),
            const SizedBox(height: 14),
            _ring(),
            const SizedBox(height: 14),
            _controls(),
            const SizedBox(height: 10),
            _bgNote(),
            const SizedBox(height: 14),
            _durationRow(),
            if (!_s.isBreak) ...[
              const SizedBox(height: 16),
              _label('What are you studying? / क्या पढ़ रहे हैं?'),
              const SizedBox(height: 8),
              _subjectPicker(),
            ],
            const SizedBox(height: 20),
            _goalCard(todaySec),
            const SizedBox(height: 12),
            _statsRow(todaySec),
            const SizedBox(height: 20),
            _label('Last 7 days / पिछले 7 दिन'),
            const SizedBox(height: 8),
            _weekChart(),
            const SizedBox(height: 20),
            _label('By subject (all time) / विषय के हिसाब से'),
            const SizedBox(height: 8),
            _subjectBars(),
            const SizedBox(height: 16),
            Text(
              '⭐ 1 XP for every focus minute. Break time is not counted. The timer follows the clock, so it stays correct even if the screen turns off.\n'
              'हर फोकस मिनट पर 1 XP। ब्रेक का समय नहीं गिना जाता। टाइमर घड़ी से चलता है, इसलिए स्क्रीन बंद होने पर भी सही रहता है।',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
    );
  }

  Widget _label(String t) => Text(t, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15));

  Widget _modeSwitch() {
    return Row(
      children: [
        Expanded(child: _pill('🎯 Focus / फोकस', !_s.isBreak, _s.running ? null : () => _s.prepare(false), big: true)),
        const SizedBox(width: 10),
        Expanded(child: _pill('☕ Break / ब्रेक', _s.isBreak, _s.running ? null : () => _s.prepare(true), big: true)),
      ],
    );
  }

  Widget _pill(String label, bool selected, VoidCallback? onTap, {bool big = false}) {
    return Opacity(
      opacity: onTap == null && !selected ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: big ? 8 : 14, vertical: big ? 12 : 8),
          decoration: BoxDecoration(
            color: selected ? AppC.gold : AppC.card2,
            borderRadius: BorderRadius.circular(big ? 14 : 20),
            border: Border.all(color: selected ? AppC.accent : Colors.transparent),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? AppC.onGold : AppC.text70,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: big ? 14 : 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring() {
    final size = math.min(250.0, MediaQuery.of(context).size.width - 90);
    final ratio = _s.totalSec <= 0 ? 0.0 : ((_s.totalSec - _s.remainSec) / _s.totalSec).clamp(0.0, 1.0).toDouble();
    final Color color = _s.isBreak ? AppC.green : AppC.accent;
    final info = _subjectInfo(_s.subject);
    final String status;
    if (_s.isBreak) {
      status = _s.running ? 'Relax… / आराम करें…' : 'Break time / ब्रेक का समय';
    } else if (_s.running) {
      status = '${info[0]} ${info[1]}';
    } else if (_s.started) {
      status = 'Paused / रुका हुआ';
    } else {
      status = 'Ready / तैयार';
    }
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(ratio, AppC.text12, color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _clock(_s.remainSec),
                    style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: size * 0.22, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(status, style: TextStyle(color: AppC.text70, fontSize: 13.5)),
                if (_s.sessionsThisRun > 0 && !_s.isBreak) ...[
                  const SizedBox(height: 4),
                  Text('✅ x${_s.sessionsThisRun}', style: TextStyle(color: AppC.green, fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final started = _s.started;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: (_s.running || started) ? _s.reset : null,
            icon: const Icon(Icons.restart_alt, size: 20),
            label: const Text('Reset / रीसेट'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppC.text,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: _s.running ? _s.pause : _s.start,
            icon: Icon(_s.running ? Icons.pause : Icons.play_arrow),
            label: Text(
              _s.running ? 'Pause / रोकें' : (started ? 'Resume / जारी रखें' : 'Start / शुरू करें'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bgNote() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(12)),
      child: Text(
        '▶ Start the timer, then go back and use Mocks / PDFs / Quiz — it keeps running and a small timer pill shows on every screen (pause / stop from there).\n'
        'टाइमर शुरू करके पीछे जाएँ और मॉक / PDF / क्विज़ चलाएँ — टाइमर चलता रहेगा, हर स्क्रीन पर छोटा टाइमर दिखेगा (वहीं से पॉज़ / स्टॉप करें)।',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppC.text, fontSize: 11.5, height: 1.4),
      ),
    );
  }

  Widget _durationRow() {
    final options = _s.isBreak ? _breakOptions : _focusOptions;
    final current = _s.isBreak ? _s.breakMin : _s.focusMin;
    final enabled = !_s.running;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final m in options) _pill('$m min', m == current, enabled ? () => _s.setMinutes(m) : null),
        _pill(options.contains(current) ? '✏️ Custom' : '✏️ $current min', !options.contains(current), enabled ? _customMinutes : null),
      ],
    );
  }

  Widget _subjectPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in StudyTimerService.subjects) _pill('${s[0]} ${s[1]}', s[1] == _s.subject, () => _s.setSubject(s[1])),
      ],
    );
  }

  Widget _goalCard(int todaySec) {
    final goalSec = _s.goalMin * 60;
    final ratio = goalSec <= 0 ? 0.0 : (todaySec / goalSec).clamp(0.0, 1.0).toDouble();
    final reached = todaySec >= goalSec;
    return GestureDetector(
      onTap: _editGoal,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reached ? '🎉 Study goal reached! / लक्ष्य पूरा!' : '🎯 Today / आज: ${_hm(todaySec)} of ${_hm(goalSec)}',
                    style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Icon(Icons.edit, size: 16, color: AppC.text54),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: ratio, minHeight: 9, backgroundColor: AppC.card, color: reached ? AppC.green : AppC.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(int todaySec) {
    var weekSum = 0;
    for (final d in _week) {
      weekSum += d.seconds;
    }
    final avg = _week.isEmpty ? 0 : weekSum ~/ 7;
    return Row(
      children: [
        _stat('Today', _hm(todaySec), AppC.accent),
        const SizedBox(width: 8),
        _stat('7-day avg', _hm(avg), AppC.text),
        const SizedBox(width: 8),
        _stat('Total', _hm(_allSec), AppC.green),
        const SizedBox(width: 8),
        _stat('Sessions', '$_sessions', AppC.text),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: AppC.muted, fontSize: 11))),
          ],
        ),
      ),
    );
  }

  Widget _weekChart() {
    final goalSec = _s.goalMin * 60;
    var maxSec = goalSec;
    for (final d in _week) {
      if (d.seconds > maxSec) maxSec = d.seconds;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _week.length; i++) _dayBar(_week[i], maxSec, goalSec, i == _week.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _dayBar(DayStudy d, int maxSec, int goalSec, bool isToday) {
    const barArea = 90.0;
    final h = (maxSec <= 0 || d.seconds <= 0) ? 3.0 : math.max(3.0, barArea * d.seconds / maxSec);
    final Color c = d.seconds <= 0 ? AppC.text24 : (d.seconds >= goalSec ? AppC.green : AppC.accent);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(d.seconds <= 0 ? '' : _hm(d.seconds), style: TextStyle(color: AppC.text70, fontSize: 10)),
            ),
            const SizedBox(height: 3),
            Container(height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Text(
              _dayNames[d.day.weekday - 1],
              style: TextStyle(color: isToday ? AppC.accent : AppC.muted, fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subjectBars() {
    final entries = _subj.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
        child: Text(
          'Finish a focus session and your subject-wise time will show here.\nएक फोकस सेशन पूरा करें, विषय-वार समय यहाँ दिखेगा।',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppC.muted, fontSize: 12, height: 1.4),
        ),
      );
    }
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (final e in entries.take(6)) _subjectRow(e.key, e.value, total),
        ],
      ),
    );
  }

  Widget _subjectRow(String key, int sec, int total) {
    final info = _subjectInfo(key);
    final ratio = total <= 0 ? 0.0 : sec / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${info[0]} ${info[1]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontSize: 13)),
              ),
              Text('${_hm(sec)}  •  ${(ratio * 100).round()}%', style: TextStyle(color: AppC.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 7, backgroundColor: AppC.card, color: AppC.accent),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color track;
  final Color color;
  const _RingPainter(this.ratio, this.track, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    if (ratio <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * ratio, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.ratio != ratio || old.track != track || old.color != color;
}
