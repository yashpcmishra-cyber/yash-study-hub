import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_globals.dart';
import 'firebase_options.dart';
import 'screens/notifications_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firestore_service.dart';

void _openNotificationsScreen() {
  appNavigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
  );
}

/// If the app was opened (from closed) by tapping a push notification, the
/// Home screen will jump straight to the Notifications screen.
Future<void> _checkLaunchedFromNotification() async {
  try {
    final initial = await FirebaseMessaging.instance
        .getInitialMessage()
        .timeout(const Duration(seconds: 2));
    if (initial != null) openNotificationsOnStart = true;
  } catch (_) {
    // Not important — the app simply opens normally.
  }
}

Future<void> _setupNotifications() async {
  // 1) Listeners first, so nothing is missed while the permission dialog
  //    is on screen.
  try {
    // App is OPEN when the push arrives: Android does not show it by
    // itself, so show a small bar with a "View" button.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      final title = (n.title ?? '').trim();
      final body = (n.body ?? '').trim();
      final text = [title, body].where((t) => t.isNotEmpty).join('\n');
      if (text.isEmpty) return;
      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'View', onPressed: _openNotificationsScreen),
        ),
      );
    });
    // App was in the background and the student tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _openNotificationsScreen();
    });
  } catch (_) {
    // ignore
  }

  // 2) Permission + topic subscription.
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    // Every install subscribes to one shared topic — the admin sends ONE
    // message to this topic and it reaches every student's phone. No need
    // to manage individual device tokens.
    await messaging.subscribeToTopic('all_students');
  } catch (_) {
    // e.g. no internet on first launch — it is tried again on the next launch.
  }
}

/// Records this install once per device, plus a tiny "active today" ping
/// (Admin Panel > Stats shows only COUNTS — never any personal info).
/// A random anonymous ID is generated on first launch. After that, the app
/// writes only ONE small "lastActiveAt" update per phone per day (the first
/// time the app is opened that day) — so Firebase's free write limit stays
/// safe. The security rules allow an unauthenticated app to change ONLY the
/// lastActiveAt field. Wrapped in try-catch so this can never block the app
/// from starting even if a write fails for any reason.
Future<void> _recordInstallOnce() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}'; // phone's local date
    final existingId = prefs.getString('anon_install_id');
    if (existingId == null) {
      // First launch on this phone: create the install record (also counts as active today).
      final anonId = '${now.microsecondsSinceEpoch}_${Random().nextInt(999999)}';
      await prefs.setString('anon_install_id', anonId);
      await prefs.setString('last_active_day', today);
      await FirestoreService().recordInstall(anonId);
    } else if (prefs.getString('last_active_day') != today) {
      // Later launch, first open today: one small "active today" update.
      await prefs.setString('last_active_day', today);
      await FirestoreService().recordActive(existingId);
    }
  } catch (_) {
    // Never let a failed install/active-count write block the app from opening.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Show the reason on screen instead of a blank/black screen, so it can
    // be photographed and fixed quickly.
    runApp(StartupErrorApp(error: e.toString()));
    return;
  }
  await _checkLaunchedFromNotification();
  // Fire-and-forget: these do network calls and must not delay the first
  // frame.
  _setupNotifications();
  _recordInstallOnce();
  runApp(const YashStudyHubApp());
}

class StartupErrorApp extends StatelessWidget {
  final String error;
  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF050B24),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'The app could not start.\n\nFirebase setup problem:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

class YashStudyHubApp extends StatelessWidget {
  const YashStudyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFFF29);
    const bg = Color(0xFF050B24);
    return MaterialApp(
      title: 'Yash Study Hub',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          primary: gold,
          surface: const Color(0xFF081136),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
        fontFamily: 'Roboto',
        // Gives every ElevatedButton in the app a raised "3D" look at rest
        // that visibly sinks when pressed, then springs back on release.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: bg,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shadowColor: Colors.black.withOpacity(0.6),
          ).copyWith(
            elevation: WidgetStateProperty.resolveWith<double>((states) {
              if (states.contains(WidgetState.pressed)) return 2;
              if (states.contains(WidgetState.disabled)) return 0;
              return 8;
            }),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
