import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed.';
    } catch (_) {
      return 'Login failed. Please check your internet connection and try again.';
    }
  }

  // Student Sign Up. This is a completely separate account from the Admin
  // account — Firestore rules only ever grant admin writes to one specific,
  // verified email (see firestore.rules), so a student signing up here can
  // never become an admin no matter what email they use.
  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed.';
    } catch (_) {
      return 'Sign up failed. Please check your internet connection and try again.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send reset email.';
    } catch (_) {
      return 'Could not send reset email. Please check your internet connection.';
    }
  }

  // Firestore/Storage rules require email_verified == true for admin
  // writes (see firestore.rules / storage.rules), so the app needs a way to
  // check that status and trigger Firebase's verification email.
  Future<bool> isEmailVerified() async {
    try {
      await _auth.currentUser?.reload(); // pick up verification done in another tab/app
    } catch (_) {
      // offline — fall back to the locally known status
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<String?> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send verification email.';
    } catch (_) {
      return 'Could not send the verification email. Please check your internet connection.';
    }
  }

  Future<void> logout() => _auth.signOut();
}
