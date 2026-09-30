import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../app_globals.dart';
import '../utils/open_link.dart';

/// Shows an "Update available" pop-up when a newer APK has been published.
///
/// How it works (nothing to do in code when you release a new APK):
///   1. Firestore document  appConfig/appVersion  holds:
///        latestBuild (number)  - the newest build number you released
///        minBuild    (number)  - optional; phones BELOW this are forced to update
///        apkUrl      (text)    - your Google Drive link to the APK
///        message     (text)    - optional line shown in the pop-up
///   2. On launch the app compares its own build number (the number after
///      the "+" in pubspec.yaml version) with those values.
///
/// It is completely silent when the document is missing, the phone is
/// offline, or anything at all goes wrong - it can never block the app.
class UpdateChecker {
  static bool _checked = false;

  static Future<void> check() async {
    if (_checked) return;
    _checked = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;

      final snap = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('appVersion')
          .get()
          .timeout(const Duration(seconds: 8));
      final data = snap.data();
      if (data == null) return;

      final latest = (data['latestBuild'] as num?)?.toInt() ?? 0;
      final minimum = (data['minBuild'] as num?)?.toInt() ?? 0;
      final url = ((data['apkUrl'] as String?) ?? '').trim();
      final message = ((data['message'] as String?) ?? '').trim();
      if (current <= 0 || url.isEmpty) return;

      final force = current < minimum;
      final optional = current < latest;
      if (!force && !optional) return;

      // The overlay sits BELOW the Navigator, so it is a safe place to
      // open a dialog from when we have no screen of our own.
      final ctx = appNavigatorKey.currentState?.overlay?.context;
      if (ctx == null || !ctx.mounted) return;

      await showDialog<void>(
        context: ctx,
        barrierDismissible: !force,
        builder: (dialogCtx) => PopScope(
          canPop: !force,
          child: AlertDialog(
            title: Text(force ? 'Update required' : 'Update available'),
            content: Text(
              message.isNotEmpty
                  ? message
                  : (force
                      ? 'Please install the latest version of Yash Study Hub to continue.'
                      : 'A new version of Yash Study Hub is available.'),
            ),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Later'),
                ),
              ElevatedButton(
                onPressed: () => openExternalLink(dialogCtx, url),
                child: const Text('Update now'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      // Stay silent - an update check must never break the app.
    }
  }
}
