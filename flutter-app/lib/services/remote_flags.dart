import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config: bina naya APK banaye app ko console se control karo.
///
/// Firebase console > Remote Config mein ye parameters banao (naam bilkul
/// aisa hi likho) aur "Publish changes" dabao:
///
///   maintenance_enabled     (Boolean)  true  -> app ke upar maintenance patti dikhe
///   maintenance_message     (String)   patti mein kya likha ho
///   feature_mock_tests      (Boolean)  false -> Home se Mock Tests tile hat jaaye
///   feature_pdf_library     (Boolean)  false -> PDF Library tile hat jaaye
///   feature_free_mcqs       (Boolean)  false -> Free MCQs tile hat jaaye
///   feature_batches         (Boolean)  false -> Paid Batches tile hat jaaye
///   feature_daily_quiz      (Boolean)  false -> Daily Quiz tile hat jaaye
///   force_update_min_build  (Number)   iss se purane build wale phone update karne par majboor
///   force_update_message    (String)   update pop-up ka message
///
/// Console mein kuch na ho to neeche ke defaults chalte hain (sab kuch normal).
/// Values app ko agli baar kholne par (ya 1 ghante baad) milti hain.
class RemoteFlags {
  /// Values badalne par badalta hai - UI isse sun kar dobara banta hai.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static FirebaseRemoteConfig? _rc;

  static const Map<String, Object> _defaults = {
    'maintenance_enabled': false,
    'maintenance_message':
        'Thodi der ke liye maintenance chal raha hai. Please baad mein try karein. / कुछ देर के लिए मेंटेनेंस चल रहा है, कृपया बाद में प्रयास करें।',
    'feature_mock_tests': true,
    'feature_pdf_library': true,
    'feature_free_mcqs': true,
    'feature_batches': true,
    'feature_daily_quiz': true,
    'force_update_min_build': 0,
    'force_update_message': '',
  };

  /// Firebase.initializeApp ke baad ek baar. Turant lautta hai (network ka
  /// intezaar nahi karta): pehle se saved values lagata hai, nayi values
  /// peeche se aati hain.
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Release mein 1 ghanta: free limit (roz 1 lakh fetch) kabhi nahi tootti.
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await rc.setDefaults(_defaults);
      _rc = rc;
      try {
        await rc.activate(); // pichli baar fetch ki hui values, bina internet ke
      } catch (_) {}
      changes.value++;
      _refresh(); // fire-and-forget
    } catch (_) {
      // Remote Config na chale to defaults se app normal chalta rahega.
    }
  }

  static Future<void> _refresh() async {
    try {
      final rc = _rc;
      if (rc == null) return;
      final changed = await rc.fetchAndActivate().timeout(const Duration(seconds: 12));
      if (changed) changes.value++;
    } catch (_) {}
  }

  static bool on(String key) {
    final d = _defaults[key];
    final fallback = d is bool ? d : true;
    try {
      return _rc?.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String text(String key) {
    final d = _defaults[key];
    final fallback = d is String ? d : '';
    try {
      final v = _rc?.getString(key);
      return (v == null) ? fallback : v.trim();
    } catch (_) {
      return fallback;
    }
  }

  static int number(String key) {
    final d = _defaults[key];
    final fallback = d is int ? d : 0;
    try {
      return _rc?.getInt(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static bool get maintenance => on('maintenance_enabled');
  static String get maintenanceMessage => text('maintenance_message');
}
