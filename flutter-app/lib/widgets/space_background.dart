import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Jis screen ka apna solid background hai (PDF viewer, video player, mock
/// test) wo ye counter badhati hai jab tak khuli hai; counter 0 se zyada ho to
/// space animation ruk jaati hai (battery bachti hai, kuch dikhta bhi nahi).
final ValueNotifier<int> spaceBackgroundPause = ValueNotifier<int>(0);

/// Poori app ke peeche chalne wala space background: taare, asteroids aur
/// kabhi-kabhi toota hua taara. Ye MaterialApp.builder mein ek hi baar
/// lagta hai, isliye har screen ko alag se kuch nahi karna padta.
/// - Animation ~30 fps par chalti hai (purane phones/battery ke liye halka).
/// - Phone mein "Remove animations" on ho to sirf ek sthir tasveer dikhti hai.
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({super.key});

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final _SkyPainter _painter;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  double _lastPaint = -1;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _painter = _SkyPainter(_time);
    _ticker = createTicker(_onTick);
    spaceBackgroundPause.addListener(_syncMute);
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncMute();
  }

  void _syncMute() {
    _ticker.muted = _reduceMotion || spaceBackgroundPause.value > 0;
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1000000.0;
    if (t - _lastPaint < 0.033) return; // ~30 fps
    _lastPaint = t;
    _time.value = t;
  }

  @override
  void dispose() {
    spaceBackgroundPause.removeListener(_syncMute);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient + nebula sirf ek baar paint hota hai (cache rehta hai).
          const RepaintBoundary(child: CustomPaint(painter: _BackdropPainter())),
          RepaintBoundary(child: CustomPaint(painter: _painter)),
          // Halka andhera, taaki text/cards hamesha saaf padhe jaayein.
          const ColoredBox(color: Color(0x40050B24)),
        ],
      ),
    );
  }
}

/// Screens ke beech halka cross-fade. Screens ka background ab transparent hai,
/// isliye slide/zoom jaisi transition mein purani aur nayi screen ek-doosre ke
/// andar se dikhti; cross-fade mein space background beech mein sthir rehta hai.
class SpaceFadeTransitionsBuilder extends PageTransitionsBuilder {
  const SpaceFadeTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: secondaryAnimation.drive(Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn))),
        child: child,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF04050D), Color(0xFF0B1233)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.6, 0.45),
          radius: 0.9,
          colors: [Color(0x336440D2), Color(0x006440D2)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.75, 0.1),
          radius: 0.8,
          colors: [Color(0x241E82D2), Color(0x001E82D2)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Star {
  const _Star(this.x, this.y, this.z, this.phase);
  final double x;
  final double y;
  final double z;
  final double phase;
}

class _Rock {
  _Rock({
    required this.x,
    required this.y,
    required this.depth,
    required this.radius,
    required this.rot0,
    required this.spin,
    required this.vx,
    required this.vy,
    required this.path,
    required this.craterAngle,
    required this.craterDist,
  });
  final double x;
  final double y;
  final double depth;
  final double radius;
  final double rot0;
  final double spin;
  final double vx;
  final double vy;
  final Path path; // radius-1 wala shape; draw karte waqt scale hota hai
  final double craterAngle;
  final double craterDist;
}

double _between(math.Random r, double a, double b) => a + r.nextDouble() * (b - a);

double _wrap(double v) {
  final r = v % 1.0;
  return r < 0 ? r + 1.0 : r;
}

List<_Star> _buildStars() {
  final r = math.Random(11);
  return List<_Star>.generate(
    80,
    (_) => _Star(r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble() * 2 * math.pi),
  );
}

List<_Rock> _buildRocks() {
  final r = math.Random(5);
  return List<_Rock>.generate(6, (_) {
    final d = _between(r, 0.35, 1.0);
    const n = 9;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi;
      final rr = _between(r, 0.68, 1.0);
      final px = math.cos(a) * rr;
      final py = math.sin(a) * rr;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return _Rock(
      x: r.nextDouble(),
      y: r.nextDouble(),
      depth: d,
      radius: _between(r, 7, 22) * d,
      rot0: r.nextDouble() * 2 * math.pi,
      spin: _between(r, -0.6, 0.6),
      vx: -_between(r, 10, 26) * d,
      vy: _between(r, 6, 16) * d,
      path: path,
      craterAngle: r.nextDouble() * 2 * math.pi,
      craterDist: _between(r, 0, 0.5),
    );
  });
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;

  static final List<_Star> _stars = _buildStars();
  static final List<_Rock> _rocks = _buildRocks();
  final Paint _paint = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;
  final Paint _streak = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final t = time.value;
    _drawStars(canvas, w, h, t);
    _drawRocks(canvas, w, h, t);
    _drawShootingStar(canvas, w, h, t);
  }

  void _drawStars(Canvas canvas, double w, double h, double t) {
    for (final s in _stars) {
      final px = _wrap(s.x - t * 0.004 * (0.3 + s.z)) * w;
      final py = _wrap(s.y + t * 0.003 * (0.3 + s.z)) * h;
      final a = (0.3 + 0.7 * s.z * (0.6 + 0.4 * math.sin(t * (1 + s.z * 2) + s.phase))).clamp(0.0, 1.0).toDouble();
      _paint.color = Color.fromRGBO(225, 235, 255, a);
      canvas.drawCircle(Offset(px, py), 0.4 + s.z * 1.1, _paint);
      if (s.z > 0.92) {
        _line.color = Color.fromRGBO(200, 220, 255, a * 0.5);
        canvas.drawLine(Offset(px - 5, py), Offset(px + 5, py), _line);
        canvas.drawLine(Offset(px, py - 5), Offset(px, py + 5), _line);
      }
    }
  }

  void _drawRocks(Canvas canvas, double w, double h, double t) {
    const m = 40.0;
    final spanX = w + 2 * m;
    final spanY = h + 2 * m;
    final sc = w / 380;
    for (final k in _rocks) {
      final px = (k.x * spanX + k.vx * t) % spanX - m;
      final py = (k.y * spanY + k.vy * t) % spanY - m;
      final rad = k.radius * sc;
      if (rad <= 0) continue;
      final op = 0.45 + 0.55 * k.depth;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(k.rot0 + k.spin * t);
      canvas.scale(rad);
      _paint.color = Color.fromRGBO(110, 108, 125, op);
      canvas.drawPath(k.path, _paint);
      _line.strokeWidth = 0.8 / rad;
      _line.color = Color.fromRGBO(255, 255, 255, 0.18 * op);
      canvas.drawPath(k.path, _line);
      _paint.color = Color.fromRGBO(30, 30, 40, 0.45 * op);
      canvas.drawCircle(Offset(math.cos(k.craterAngle) * k.craterDist, math.sin(k.craterAngle) * k.craterDist), 0.22, _paint);
      canvas.restore();
    }
    _line.strokeWidth = 0.6;
  }

  void _drawShootingStar(Canvas canvas, double w, double h, double t) {
    const period = 9.0;
    const life = 0.9;
    final cycle = (t / period).floor();
    final ph = t - cycle * period;
    if (ph >= life) return;
    final r = math.Random(cycle * 7919 + 13);
    final sx = w * (0.4 + 0.6 * r.nextDouble());
    final sy = h * 0.3 * r.nextDouble();
    final vx = -w * 0.9;
    final vy = w * 0.45;
    final head = Offset(sx + vx * ph, sy + vy * ph);
    final tail = Offset(head.dx - vx * 0.14, head.dy - vy * 0.14);
    final a = (1 - ph / life).clamp(0.0, 1.0).toDouble();
    _streak.shader = ui.Gradient.linear(
      head,
      tail,
      [Color.fromRGBO(255, 255, 255, a), const Color(0x00FFFFFF)],
    );
    canvas.drawLine(head, tail, _streak);
    _streak.shader = null;
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => false;
}
