import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_globals.dart';
import '../screens/study_timer_screen.dart';
import '../services/study_timer_service.dart';

/// Poori app ke upar tairta chhota Study Timer pill (main.dart ke Stack me).
/// Timer chal raha ho (ya beech me ruka ho) aur Study Timer screen band ho,
/// tab har screen par dikhta hai: time dekho, pause / play, stop.
/// Pill ko ungli se khinch kar kahin bhi rakh sakte hain; pill par tap
/// karne se Study Timer screen khulti hai.
/// Firestore ko 0 reads / 0 writes.
class StudyTimerMiniBar extends StatefulWidget {
  const StudyTimerMiniBar({super.key});

  @override
  State<StudyTimerMiniBar> createState() => _StudyTimerMiniBarState();
}

class _StudyTimerMiniBarState extends State<StudyTimerMiniBar> {
  static const double _w = 176;
  static const double _h = 44;
  static const Color _dark = Color(0xFF081136);

  final StudyTimerService _s = StudyTimerService.instance;
  Offset? _pos;

  @override
  void initState() {
    super.initState();
    _s.openHandler = _openTimerScreen;
    _s.init(); // saved settings + (agar app band hui thi to) chalta timer wapas
  }

  void _openTimerScreen() {
    appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const StudyTimerScreen()));
  }

  Offset _clamp(Offset o, Size size, EdgeInsets pad) {
    final minY = pad.top + 4;
    final maxY = math.max(minY, size.height - pad.bottom - _h - 4);
    final maxX = math.max(4.0, size.width - _w - 4);
    return Offset(o.dx.clamp(4.0, maxX).toDouble(), o.dy.clamp(minY, maxY).toDouble());
  }

  static String _clock(int sec) {
    final s = sec < 0 ? 0 : sec;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _s,
      builder: (context, _) {
        if (!_s.active || _s.screenOpen) {
          return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
        }
        final mq = MediaQuery.of(context);
        final size = mq.size;
        final def = Offset(size.width - _w - 10, size.height - mq.padding.bottom - 150);
        final pos = _clamp(_pos ?? def, size, mq.padding);
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _pos = _clamp(pos + d.delta, size, mq.padding)),
            child: _pill(),
          ),
        );
      },
    );
  }

  Widget _pill() {
    final bg = _s.isBreak ? const Color(0xFF69F0AE) : const Color(0xFFFFD400);
    final iconStyle = const IconThemeData(color: _dark, size: 22);
    return Material(
      color: bg,
      elevation: 8,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: _w,
        height: _h,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _s.openScreen,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Text(_s.isBreak ? '☕' : '⏱️', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _clock(_s.remainSec),
                            style: TextStyle(
                              color: _dark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: TextDecoration.none,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              // Ruka hua ho to thoda halka dikhta hai.
                              fontStyle: _s.running ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _s.running ? _s.pause : _s.start,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                child: IconTheme(data: iconStyle, child: Icon(_s.running ? Icons.pause : Icons.play_arrow)),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _s.reset,
              child: Padding(
                padding: const EdgeInsets.only(left: 3, right: 12, top: 10, bottom: 10),
                child: IconTheme(data: iconStyle, child: const Icon(Icons.stop)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
