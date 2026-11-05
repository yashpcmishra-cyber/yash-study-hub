import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  NotifyPrefs - student ne kaun-se notification topics ON kiye hain.
//  Choice phone me (SharedPreferences) rehti hai, aur har app start par un
//  topics ko dobara subscribe kiya jata hai (reinstall / naye token ke baad bhi).
//  Firestore ko 0 reads / 0 writes.
// =============================================================================
class NotifyPrefs {
  NotifyPrefs._();

  static const _kTopics = 'ysh5_notify_topics'; // jo topics student ne ON kiye

  static Future<Set<String>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_kTopics) ?? <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Topic ON/OFF karta hai. Internet na ho ya subscribe fail ho to false deta hai
  /// aur purani choice waisi hi rehti hai.
  static Future<bool> setTopic(String topic, bool on) async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (on) {
        await messaging.subscribeToTopic(topic);
      } else {
        await messaging.unsubscribeFromTopic(topic);
      }
    } catch (_) {
      return false;
    }
    try {
      final p = await SharedPreferences.getInstance();
      final s = (p.getStringList(_kTopics) ?? <String>[]).toSet();
      if (on) {
        s.add(topic);
      } else {
        s.remove(topic);
      }
      await p.setStringList(_kTopics, s.toList());
    } catch (_) {}
    return true;
  }

  /// App start par: saved topics dobara subscribe (kuch fail ho to agli baar phir try hoga).
  static Future<void> resubscribeSaved() async {
    final saved = await load();
    for (final t in saved) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(t);
      } catch (_) {}
    }
  }
}
