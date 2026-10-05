import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_globals.dart';
import '../services/firestore_service.dart';
import 'auth/login_screen.dart';
import 'profile/profile_screen.dart';
import 'home_screen.dart';
import '../services/update_checker.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    // One loop = 3s = one full flag wave and two blinks of logo / Jai Hind.
    _wave = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    // Was 1400ms. 3000ms shows the full animation once; change if you want.
    Timer(const Duration(milliseconds: 3000), _route);
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  // First-run gate: not logged in -> Login/SignUp. Logged in but profile
  // not filled yet (State/District/Gender/Qualification) -> Profile setup.
  // Logged in + profile complete -> straight to Home.
  Future<void> _route() async {
    await _routeInner();
    // Once the student is on Login/Home, quietly check for a newer APK.
    UpdateChecker.check();
  }

  Future<void> _routeInner() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    try {
      final profile = await FirestoreService().getStudentProfile(user.uid).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (profile == null || !profile.profileComplete) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileScreen(isSetup: true)));
      } else {
        await syncLocalStudentIdentity(user.email ?? '', profile.name);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (_) {
      // Offline on launch — do not lock an already-logged-in, previously
      // completed student out of the app; let Home load (it works offline
      // via Firestore's local cache). The Profile tab will show the last
      // known details once back online.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A24),
      body: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight, bh = h / 3, cx = w / 2;
        final logoSize = math.min(130.0, bh * 0.62);
        final jaiSize = math.min(w * 0.14, 60.0);

        final logo = Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(logoSize * 0.2),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🎓', style: TextStyle(fontSize: 50)))),
        );
        final jaiHind = Text(
          'जय हिन्द',
          style: TextStyle(
            color: Colors.white,
            fontSize: jaiSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Color(0x73000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
        );

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _wave,
            builder: (_, __) {
              final t = _wave.value;
              // 2 blinks per 3s loop (every 1.5s), never fully invisible.
              final blink = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2));
              final dy = _flagOff(cx, w, h, t);
              final angle = math.atan((_flagOff(cx + 2, w, h, t) - _flagOff(cx - 2, w, h, t)) / 4);

              // Places a widget at the centre of a band so it moves with the cloth.
              Widget onFlag(double centerY, Widget child) => Positioned(
                    left: 0,
                    right: 0,
                    top: centerY + dy - 100,
                    height: 200,
                    child: Center(
                      child: Transform.rotate(angle: angle, child: Opacity(opacity: blink, child: child)),
                    ),
                  );

              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _WavingFlagPainter(t)),
                  onFlag(bh / 2, logo), // saffron band
                  onFlag(2.5 * bh, jaiHind), // green band
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

/// Vertical ripple of the flag at horizontal position x.
/// The pole side (left) moves little, the free end (right) moves more.
double _flagOff(double x, double w, double h, double t) {
  final p = x / w;
  return math.sin(p * 1.6 * 2 * math.pi - t * 2 * math.pi) * (h * 0.018) * (0.35 + 0.65 * p);
}

/// Full-screen Indian flag that ripples like cloth.
/// Pure Dart (CustomPainter): no package, no video, no extra asset.
class _WavingFlagPainter extends CustomPainter {
  final double t; // 0..1, loops
  _WavingFlagPainter(this.t);

  static const _saffron = Color(0xFFFF9933);
  static const _white = Color(0xFFFFFFFF);
  static const _green = Color(0xFF138808);
  static const _navy = Color(0xFF000080);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double off(double x) => _flagOff(x, w, h, t);

    const step = 6.0;
    final n = (w / step).ceil();
    final amp = h * 0.018;
    final top = -3 * amp, bottom = h + 3 * amp;
    final bandH = h / 3;

    // Tricolour bands (edges follow the wave)
    final bands = <List<dynamic>>[
      [_saffron, top, bandH + 1],
      [_white, bandH, 2 * bandH + 1],
      [_green, 2 * bandH, bottom],
    ];
    for (final b in bands) {
      final y0 = b[1] as double, y1 = b[2] as double;
      final path = Path()..moveTo(0, y0 + off(0));
      for (var i = 1; i <= n; i++) {
        final x = math.min(i * step, w);
        path.lineTo(x, y0 + off(x));
      }
      for (var i = n; i >= 0; i--) {
        final x = math.min(i * step, w);
        path.lineTo(x, y1 + off(x));
      }
      path.close();
      canvas.drawPath(path, Paint()..color = b[0] as Color);
    }

    // Ashoka Chakra (24 spokes) on the white band, riding the wave
    final cx = w / 2, cy = h / 2;
    final r = bandH * 0.42;
    final slope = (off(cx + 2) - off(cx - 2)) / 4;
    canvas.save();
    canvas.translate(cx, cy + off(cx));
    canvas.rotate(math.atan(slope));
    final ring = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07;
    final spoke = Paint()
      ..color = _navy
      ..strokeWidth = r * 0.03;
    canvas.drawCircle(Offset.zero, r, ring);
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * math.pi / 24;
      canvas.drawLine(
        Offset(math.cos(a) * r * 0.12, math.sin(a) * r * 0.12),
        Offset(math.cos(a) * r * 0.96, math.sin(a) * r * 0.96),
        spoke,
      );
    }
    canvas.drawCircle(Offset.zero, r * 0.1, Paint()..color = _navy);
    canvas.restore();

    // Fabric light/shadow: strips brighten or darken with the wave slope
    for (var i = 0; i < n; i++) {
      final x0 = i * step, x1 = x0 + step;
      final d = (off(x1) - off(x0)) / step;
      final s = (d * 1.1).clamp(-0.28, 0.28);
      final c = s >= 0 ? Colors.black.withAlpha((s * 255).round()) : Colors.white.withAlpha((-s * 0.7 * 255).round());
      canvas.drawRect(Rect.fromLTRB(x0, top, x1 + 0.5, bottom), Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant _WavingFlagPainter old) => old.t != t;
}
