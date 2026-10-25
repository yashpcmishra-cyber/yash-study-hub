import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';
import '../widgets/study_time_chart.dart';

enum _Mode { focus, shortBreak, longBreak }

/// Study Timer (Pomodoro): Focus + Break. Jitna time focus me padha, wo aaj ke
/// khate me judta hai aur hafte ke chart me dikhta hai. Sirf phone me,
/// Firestore ko 0 reads / 0 writes.
class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> with WidgetsBindingObserver {
  static const List<int> _focusOptions = [15, 25, 45, 60];
  static const int _shortMin = 5;
  static const int _longMin = 15;

  _Mode _mode = _Mode.focus;
  int _focusMin = 25;
  bool _running = false;
  int _totalSec = 25 * 60;
  int _remainingSec = 25 * 60;
  DateTime? _endAt;
  int _credited = 0; // is round ke kitne second khate me jud chuke
  int _cycle = 0; // is screen par kitne focus round pure hue
  int _todaySec = 0;
  int _sessions = 0;
  Timer? _ticker;

  bool get _guard => _running && _mode == _Mode.focus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    if (_mode == _Mode.focus && _running) {
      _flush(); // jitna padha wo save ho jaaye
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  Future<void> _loadStats() async {
    try {
      final t = await StudyTimeStore.secondsOn(StudyStore.today());
      final s = await StudyTimeStore.totalSessions();
      if (!mounted) return;
      setState(() {
        _todaySec = t;
        _sessions = s;
      });
    } catch (_) {}
  }

  int _secondsFor(_Mode m) {
    switch (m) {
      case _Mode.focus:
        return _focusMin * 60;
      case _Mode.shortBreak:
        return _shortMin * 60;
      case _Mode.longBreak:
        return _longMin * 60;
    }
  }

  void _setMode(_Mode m) {
    if (_running) return;
    setState(() {
      _mode = m;
      _totalSec = _secondsFor(m);
      _remainingSec = _totalSec;
      _credited = 0;
    });
  }

  void _setFocusMin(int min) {
    if (_running) return;
    setState(() {
      _focusMin = min;
      if (_mode == _Mode.focus) {
        _totalSec = min * 60;
        _remainingSec = _totalSec;
        _credited = 0;
      }
    });
  }

  void _start() {
    if (_running || _remainingSec <= 0) return;
    _endAt = DateTime.now().add(Duration(seconds: _remainingSec));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    setState(() => _running = true);
  }

  void _tick() {
    final end = _endAt;
    if (!_running || end == null) return;
    final leftMs = end.difference(DateTime.now()).inMilliseconds;
    final sec = (leftMs / 1000).ceil();
    if (sec <= 0) {
      _complete();
    } else if (sec != _remainingSec && mounted) {
      setState(() => _remainingSec = sec);
    }
  }

  /// Focus ka jitna time ab tak guzra, usme se jo khate me nahi gaya wo jod do.
  Future<void> _flush() async {
    if (_mode != _Mode.focus) return;
    final elapsed = _totalSec - _remainingSec;
    final delta = elapsed - _credited;
    if (delta <= 0) return;
    _credited += delta;
    await StudyTimeStore.addSeconds(delta);
    try {
      final t = await StudyTimeStore.secondsOn(StudyStore.today());
      if (mounted) setState(() => _todaySec = t);
    } catch (_) {}
  }

  Future<void> _pause() async {
    _ticker?.cancel();
    if (mounted) setState(() => _running = false);
    await _flush();
  }

  Future<void> _reset() async {
    _ticker?.cancel();
    if (mounted) setState(() => _running = false);
    await _flush();
    if (!mounted) return;
    setState(() {
      _remainingSec = _totalSec;
      _credited = 0;
    });
  }

  Future<void> _complete() async {
    _ticker?.cancel();
    if (!mounted) return;
    final wasFocus = _mode == _Mode.focus;
    setState(() {
      _running = false;
      _remainingSec = 0;
    });
    HapticFeedback.heavyImpact();
    await _flush();
    if (wasFocus) {
      await StudyTimeStore.addSession();
      _cycle++;
      await _loadStats();
    }
    if (!mounted) return;
    final next = wasFocus ? (_cycle % 4 == 0 ? _Mode.longBreak : _Mode.shortBreak) : _Mode.focus;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card2,
        title: Text(
          wasFocus ? 'Great focus! 🎉 / शाबाश!' : 'Break over ⏰ / ब्रेक खत्म',
          style: TextStyle(color: AppC.text, fontSize: 17),
        ),
        content: Text(
          wasFocus
              ? 'You studied $_focusMin minutes. Take a break now.\nआपने $_focusMin मिनट पढ़ाई की। अब थोड़ा ब्रेक लीजिए।'
              : 'Ready for the next focus round?\nअगले फोकस राउंड के लिए तैयार?',
          style: TextStyle(color: AppC.text70, fontSize: 13.5, height: 1.35),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
    if (!mounted) return;
    _setMode(next);
  }

  Future<bool> _confirmLeave() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card2,
        title: Text('Stop the timer? / टाइमर रोकें?', style: TextStyle(color: AppC.text, fontSize: 16)),
        content: Text(
          'The timer runs only on this screen. Time studied so far will be saved.\nटाइमर सिर्फ़ इसी स्क्रीन पर चलता है। अब तक की पढ़ाई सेव हो जाएगी।',
          style: TextStyle(color: AppC.text70, fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Stop & exit', style: TextStyle(color: AppC.red))),
        ],
      ),
    );
    return r == true;
  }

  static String _clock(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _modeLabel {
    switch (_mode) {
      case _Mode.focus:
        return 'Focus / फोकस';
      case _Mode.shortBreak:
        return 'Short break / छोटा ब्रेक';
      case _Mode.longBreak:
        return 'Long break / लंबा ब्रेक';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _totalSec <= 0 ? 0.0 : (_remainingSec / _totalSec).clamp(0.0, 1.0).toDouble();
    final started = _remainingSec != _totalSec;
    return PopScope(
      canPop: !_guard,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!leave) return;
        await _pause();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Study Timer')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _modeChip(_Mode.focus, 'Focus'),
                const SizedBox(width: 8),
                _modeChip(_Mode.shortBreak, 'Short break'),
                const SizedBox(width: 8),
                _modeChip(_Mode.longBreak, 'Long break'),
              ],
            ),
            if (_mode == _Mode.focus) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final m in _focusOptions) ...[
                    _lenChip(m),
                    if (m != _focusOptions.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 22),
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 10,
                        backgroundColor: AppC.text12,
                        color: _mode == _Mode.focus ? AppC.accent : AppC.green,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_clock(_remainingSec), style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 52)),
                        const SizedBox(height: 2),
                        Text(_modeLabel, style: TextStyle(color: AppC.text70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _running ? _pause : _start,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause / रोकें' : (started ? 'Resume / जारी रखें' : 'Start / शुरू करें')),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: (_running || started) ? _reset : null,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _stat('Today / आज', StudyTimeStore.fmt(_todaySec)),
                const SizedBox(width: 10),
                _stat('Sessions / सेशन', '$_sessions'),
              ],
            ),
            const SizedBox(height: 14),
            const StudyTimeChart(),
            const SizedBox(height: 12),
            Text(
              'Tip: 25 min focus + 5 min break. After 4 rounds take a long break.\nटिप: 25 मिनट फोकस + 5 मिनट ब्रेक। 4 राउंड के बाद लंबा ब्रेक लें।',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(_Mode m, String label) {
    final on = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setMode(m),
        child: Opacity(
          opacity: (_running && !on) ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? AppC.gold : AppC.cardA60, borderRadius: BorderRadius.circular(12)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: on ? AppC.onGold : AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lenChip(int min) {
    final on = _focusMin == min;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFocusMin(min),
        child: Opacity(
          opacity: (_running && !on) ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppC.goldWash2 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? AppC.accent : AppC.text24),
            ),
            child: Text('$min min', style: TextStyle(color: on ? AppC.accent : AppC.text70, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 20))),
            const SizedBox(height: 3),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: AppC.muted, fontSize: 11))),
          ],
        ),
      ),
    );
  }
}
