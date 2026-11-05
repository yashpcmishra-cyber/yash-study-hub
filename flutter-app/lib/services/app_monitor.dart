import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Crashlytics (crash reports) + Analytics (kaun-si screen kitni chalti hai).
///
/// Dono FREE hain, koi quota nahi. Sab kuch try/catch mein hai, isliye
/// agar Firebase kuch bhi galat de, app kabhi nahi rukta.
///
/// Debug mode mein (flutter run) reports band rehti hain, sirf release APK
/// se hi data jaata hai.
class AppMonitor {
  static bool _ready = false;

  /// MaterialApp(navigatorObservers: [AppMonitor.observer]) mein lagta hai.
  static final NavigatorObserver observer = _ScreenObserver();

  /// Firebase.initializeApp ke turant baad ek baar bulao.
  static Future<void> init() async {
    try {
      final on = !kDebugMode;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(on);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(on);

      // Flutter framework ke errors (widget build, layout, etc.)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        if (on) FirebaseCrashlytics.instance.recordFlutterError(details);
      };
      // Jo errors kahin pakde nahi gaye (async code ke andar).
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        if (on) FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _ready = true;
    } catch (_) {
      // Monitoring fail ho to bhi app chalna chahiye.
    }
  }

  /// Student ne jo exam chune (Analytics mein audience banane ke kaam aata hai).
  static void setExams(List<String> ids) {
    if (!_ready) return;
    try {
      final v = ids.isEmpty ? 'none' : ids.join('_');
      FirebaseAnalytics.instance.setUserProperty(name: 'exam', value: v.length > 36 ? v.substring(0, 36) : v);
    } catch (_) {}
  }

  /// Koi bhi khaas event (jaise 'exam_selected').
  static void event(String name, [Map<String, Object>? params]) {
    if (!_ready) return;
    try {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  /// Screen dekhi gayi (Home ke tabs jaisi cheezon ke liye haath se).
  static void screen(String name) {
    if (!_ready || name.isEmpty) return;
    try {
      FirebaseAnalytics.instance.logScreenView(screenName: name, screenClass: name);
    } catch (_) {}
  }
}

/// Har nayi screen khulne par Analytics ko screen ka naam bhejta hai.
/// Route ka naam na ho to screen ka class-name (jaise MockTestsScreen) liya
/// jaata hai - isiliye build mein --obfuscate band kiya gaya hai.
class _ScreenObserver extends NavigatorObserver {
  String? _last;

  void _track(Route<dynamic>? route) {
    if (route == null) return;
    final name = _nameOf(route);
    if (name == null || name == _last) return;
    _last = name;
    AppMonitor.screen(name);
  }

  String? _nameOf(Route<dynamic> route) {
    if (route is! PageRoute) return null; // dialogs / bottom sheets ginti mein nahi
    final n = route.settings.name;
    if (n != null && n.isNotEmpty && n != '/') return n;
    if (route is MaterialPageRoute) {
      try {
        final ctx = navigator?.context;
        if (ctx != null) {
          final t = route.builder(ctx).runtimeType.toString();
          if (t.isNotEmpty && !t.startsWith('_')) return t;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _track(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(previousRoute);
}
