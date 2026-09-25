import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared keys so push-notification callbacks (which have no BuildContext)
/// can show a message or open a screen.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Becomes true when the app was launched by tapping a push notification.
/// The Home screen reads it once and opens the Notifications screen.
bool openNotificationsOnStart = false;

/// batches_screen.dart / pdf_library_screen.dart / mock_test_attempt_screen.dart
/// were all written before student login existed, and read the student's
/// email straight from SharedPreferences ("student_email") to show unlock
/// badges / gate paid content / tag test attempts. Rather than touch all
/// three, every place that logs a student in (Login, Sign Up, Profile
/// Setup, and app-restart in splash_screen.dart) calls this once so that
/// saved value always matches the real logged-in account.
Future<void> syncLocalStudentIdentity(String email, String name) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_email', email.trim());
    await prefs.setString('student_name', name.trim());
  } catch (_) {
    // Best-effort only — worst case, unlock badges just don't show until
    // the next successful sync.
  }
}
