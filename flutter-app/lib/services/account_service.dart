import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_globals.dart';

/// "Delete Account" for students (Profile screen -> top bar).
///
/// Order matters and is deliberate:
///  1. Re-check the password FIRST. Firebase refuses to delete a login that
///     was not verified recently, so if this fails nothing has been touched yet.
///  2. Delete the student's data from Firestore (needs the student to still be
///     logged in, because the security rules check request.auth.uid).
///     If this fails, we STOP and do not delete the login - otherwise the
///     student would believe their data is gone while it is still stored.
///  3. Delete the Firebase login (Auth user) itself.
///  4. Clear what is saved on this phone.
///
/// Returns null on success, or a short message to show the student.
///
/// What is deleted:   students/{uid}  and every doubt in `queries` with their uid
///                    (+ best-effort: mock attempts saved under their email).
/// What is KEPT:      batchAccess / accessRequests (the admin's payment & access
///                    record - students cannot edit those) and mockScores
///                    (anonymous rank numbers, no name / email inside).
class AccountService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<String?> deleteAccount(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return 'You are not logged in. / आप लॉगिन नहीं हैं।';
    }
    if (password.isEmpty) {
      return 'Please enter your password. / अपना पासवर्ड डालें।';
    }

    // 1) Verify the password.
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: password));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Wrong password. / पासवर्ड गलत है।';
        case 'too-many-requests':
          return 'Too many attempts. Please try again after some time. / बहुत ज़्यादा कोशिशें हो गईं, कुछ देर बाद दोबारा कोशिश करें।';
        case 'network-request-failed':
          return 'No internet connection. / इंटरनेट नहीं है।';
        default:
          return e.message ?? 'Could not verify your password.';
      }
    } catch (_) {
      return 'Could not verify your password. Check your internet connection and try again.';
    }

    final uid = user.uid;

    // 2) Delete the data. Anything that fails here stops the whole process.
    try {
      // 2a) the student's doubts (the rule only allows the uid == own uid query)
      await _deleteAll(_db.collection('queries').where('uid', isEqualTo: uid));
    } on FirebaseException catch (e) {
      return _dataError(e);
    } catch (_) {
      return _dataError(null);
    }

    // 2b) Mock attempts saved under the student's email (the teacher's score
    // list). Best-effort: the rules may not allow students to touch these,
    // and that must not block the deletion.
    try {
      await _deleteAll(_db.collection('mockTestAttempts').where('studentEmail', isEqualTo: email));
    } catch (_) {
      // ignore
    }

    // 2c) The profile itself - last, so a half-finished run can simply be retried.
    try {
      await _db.collection('students').doc(uid).delete();
    } on FirebaseException catch (e) {
      return _dataError(e);
    } catch (_) {
      return _dataError(null);
    }

    // 3) Delete the login.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return 'Your data was deleted, but the internet dropped before the login could be removed. Please try again.';
      }
      return e.message ?? 'Could not delete the login. Please try again.';
    } catch (_) {
      return 'Could not delete the login. Please try again.';
    }

    // 4) Forget everything saved on this phone.
    await clearLocalStudentData();
    return null;
  }

  String _dataError(FirebaseException? e) {
    if (e != null && e.code == 'permission-denied') {
      return "Couldn't delete your data (permission denied). Please contact support: officialteamysh@gmail.com";
    }
    return "Couldn't delete your data. Please check your internet connection and try again. Nothing was removed.";
  }

  // Deletes every document a query returns, in chunks.
  Future<void> _deleteAll(Query<Map<String, dynamic>> q) async {
    final snap = await q.get();
    var batch = _db.batch();
    var pending = 0;
    for (final d in snap.docs) {
      batch.delete(d.reference);
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = _db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }
}
