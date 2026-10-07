import 'dart:async';
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2000), _route);
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
    // Peeche ka space background poori app ke liye main.dart mein lagta hai.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(color: Color(0x73829FFF), blurRadius: 60),
                        BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 12)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🎓', style: TextStyle(fontSize: 60)))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Yash Study Hub', style: TextStyle(color: Color(0xFFFFFF29), fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('COMPETITIVE EXAM PREP', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          // Neeche "Welcome" line: logo ke baad dheere se ubharti hai.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + 56,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xCCFFFF29),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(color: Color(0xFFD7DCF2), fontSize: 15, letterSpacing: 0.6),
                      children: [
                        TextSpan(text: 'Welcome to the '),
                        TextSpan(
                          text: 'Yash Study Hub',
                          style: TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
