import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'admin_panel_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _loading = false;
  // Firestore/Storage rules require email_verified == true for every admin
  // write. When true, the logged-in Firebase user's email isn't verified
  // yet, so we show a "check your inbox" screen instead of the panel
  // (otherwise every Add/Save/Delete in the panel would silently fail with
  // a permission-denied error).
  bool _needsVerification = false;
  bool _resendBusy = false;
  String? _resendMsg;

  @override
  void initState() {
    super.initState();
    // Real persistent login: Firebase Auth keeps the session across app
    // restarts automatically. If already logged in, skip straight past the
    // form (still re-checking verification status below).
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _afterLogin());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // Every student is logged in too now (student login is mandatory), so a
  // logged-in account is NOT necessarily the admin. The security rules only
  // accept the admin, so one harmless admin-only read (the install counter)
  // tells us whether this account really is the admin. Only an explicit
  // "permission-denied" blocks; any other problem (offline etc.) lets the
  // admin through exactly as before.
  Future<bool> _isRealAdmin() async {
    try {
      await FirestoreService().installCount();
      return true;
    } on FirebaseException catch (e) {
      return e.code != 'permission-denied';
    } catch (_) {
      return true;
    }
  }

  // Opens the panel if this (verified) account is the admin; otherwise stays
  // on the login form with a clear message, so the admin can log in properly.
  Future<void> _openPanelIfAdmin() async {
    final isAdmin = await _isRealAdmin();
    if (!mounted) return;
    if (isAdmin) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
    } else {
      setState(() {
        _needsVerification = false;
        _error = 'This account is not the admin account. Log in with the admin email below. / Ye admin account nahi hai — neeche admin email se login karo.';
      });
    }
  }

  Future<void> _afterLogin() async {
    final verified = await _auth.isEmailVerified();
    if (!mounted) return;
    if (verified) {
      await _openPanelIfAdmin();
    } else {
      setState(() => _needsVerification = true);
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _auth.login(_email.text, _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      await _afterLogin();
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resendBusy = true;
      _resendMsg = null;
    });
    final err = await _auth.sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _resendBusy = false;
      _resendMsg = err ?? 'Verification email sent \u2014 check your inbox (and spam folder).';
    });
  }

  Future<void> _iVerified() async {
    final verified = await _auth.isEmailVerified();
    if (!mounted) return;
    if (verified) {
      await _openPanelIfAdmin();
    } else {
      setState(() => _resendMsg = 'Still not showing as verified \u2014 after clicking the link, wait 10-15 seconds and try again.');
    }
  }

  Future<void> _useDifferentAccount() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() {
      _needsVerification = false;
      _resendMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsVerification) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify Email')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread, color: Color(0xFFFFFF29), size: 40),
                const SizedBox(height: 16),
                Text(
                  'Your admin email (${_auth.currentUser?.email ?? ''}) is not verified yet.\nYou must verify it once before you can use the Admin Panel.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                _resendBusy
                    ? const CircularProgressIndicator()
                    : ElevatedButton(onPressed: _resend, child: const Text('Send verification email')),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _iVerified, child: const Text('I have verified \u2014 continue')),
                TextButton(onPressed: _useDifferentAccount, child: const Text('Use a different account')),
                if (_resendMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_resendMsg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, color: Color(0xFFFFFF29), size: 40),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Admin email', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pass,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: Colors.grey)),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _login, child: const Text('Login')),
            ],
          ),
        ),
      ),
    );
  }
}
