import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_globals.dart';
import '../services/firestore_service.dart';
import 'auth/login_screen.dart';
import 'profile/profile_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), _route);
  }

  // First-run gate: not logged in -> Login/SignUp. Logged in but profile
  // not filled yet (State/District/Gender/Qualification) -> Profile setup.
  // Logged in + profile complete -> straight to Home.
  Future<void> _route() async {
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🎓', style: TextStyle(fontSize: 60)))),
            ),
            const SizedBox(height: 20),
            const Text('Yash Study Hub', style: TextStyle(color: Color(0xFFFFFF29), fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('COMPETITIVE EXAM PREP', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
