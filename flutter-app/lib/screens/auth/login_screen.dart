import 'package:flutter/material.dart';
import '../../app_globals.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../home_screen.dart';
import '../profile/profile_screen.dart';
import 'signup_screen.dart';

/// The very first screen a student sees if they are not logged in yet.
/// Splash screen decides whether to show this (see splash_screen.dart).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _fs = FirestoreService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter both email and password. / Email aur password dono daalo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _auth.login(email, pass);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    // Logged in — now check whether this student has already completed
    // their profile (State/District/Gender/Qualification).
    try {
      final uid = _auth.currentUser!.uid;
      final profile = await _fs.getStudentProfile(uid);
      if (!mounted) return;
      if (profile == null || !profile.profileComplete) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileScreen(isSetup: true)));
      } else {
        await syncLocalStudentIdentity(email, profile.name);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (_) {
      if (!mounted) return;
      // Offline right after login — still let them in, Home/Profile will
      // retry loading the profile themselves.
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password?". / Pehle upar email daalo.');
      return;
    }
    final err = await _auth.resetPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Password reset link sent to $email / Reset link bhej diya gaya.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFFF29);
    return Scaffold(
      backgroundColor: const Color(0xFF050B24),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 18),
                    alignment: Alignment.center,
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('🎓', style: TextStyle(fontSize: 40))),
                  ),
                ),
                const Text('Welcome back', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                const Text('Login to continue / Jaari rakhne ke liye login karo', style: TextStyle(color: Colors.grey, fontSize: 12.5), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.email_outlined, color: Colors.grey)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot password?', style: TextStyle(color: gold, fontSize: 12.5)),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5), textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Login'),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New here? ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                      child: const Text('Create Profile', style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
