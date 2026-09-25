import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../profile/profile_screen.dart';

/// Step 1 of the mandatory first-run flow: create an account with an email
/// + a password the student chooses. Step 2 (State/District/Gender/
/// Qualification) happens right after, in ProfileScreen(isSetup: true).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = AuthService();
  final _fs = FirestoreService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _password.text;
    final confirm = _confirm.text;
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name. / Apna pura naam daalo.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email. / Sahi email daalo.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters. / Password kam se kam 6 characters ka ho.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match. / Dono password same nahi hain.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _auth.signUp(email, pass);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    // Account created — save the starting profile doc (name + email),
    // profileComplete stays false until Step 2 is finished.
    try {
      final uid = _auth.currentUser!.uid;
      await _fs.saveStudentProfile(StudentModel(uid: uid, name: name, email: email, profileComplete: false));
    } catch (_) {
      // Not fatal — ProfileScreen will just start from blank fields.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileScreen(isSetup: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B24),
      appBar: AppBar(title: const Text('Create Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create your student account\napna student account banao', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Full Name *', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.person_outline, color: Colors.grey)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Email *', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.email_outlined, color: Colors.grey)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password (min 6 characters) *',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Confirm Password *', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.lock_outline, color: Colors.grey)),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Account & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
