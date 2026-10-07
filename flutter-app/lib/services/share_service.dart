import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

/// Opens the phone's normal share menu (WhatsApp, Telegram, Instagram,
/// Facebook ...) with a ready-made message + the app download link.
///
/// The message NEVER contains a PDF / Drive / video / test link - only the
/// title and the app link - so nothing can be passed around outside the app.
/// Paid batches only get a promo message (name + app link).
class ShareService {
  static const _appName = 'Yash Study Hub';

  // The app download link is read once from Firestore (appConfig/appVersion ->
  // apkUrl, the same field the update pop-up uses) and kept for the session,
  // so sharing costs at most ONE read per app launch.
  static String? _cachedLink;

  static Future<String> _appLink() async {
    final cached = _cachedLink;
    if (cached != null) return cached;
    var link = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('appVersion')
          .get()
          .timeout(const Duration(seconds: 6));
      link = ((snap.data()?['apkUrl'] as String?) ?? '').trim();
    } catch (_) {
      // offline / no document: fall back below
    }
    if (link.isEmpty) return const AppConfigModel().telegramUrl; // not cached, so we retry next time
    return _cachedLink = link;
  }

  static Future<void> _send(BuildContext context, String head, String line) async {
    try {
      final link = await _appLink();
      await Share.share('$head\n\n$line\n\n\u{1F4F2} App download: $link', subject: '$_appName - $head');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open share. Try again.")));
      }
    }
  }

  /// Free mock test (or a whole free mock folder).
  static Future<void> freeMock(BuildContext context, String title, {bool folder = false}) => _send(
        context,
        folder ? '\u{1F4DD} Free Mock Tests: $title' : '\u{1F4DD} Free Mock Test: $title',
        '$_appName app mein bilkul free practice karo.',
      );

  /// Free PDF (or a whole free PDF folder).
  static Future<void> freePdf(BuildContext context, String title, {bool folder = false}) => _send(
        context,
        folder ? '\u{1F4C1} Free PDFs: $title' : '\u{1F4C4} Free PDF: $title',
        '$_appName app mein free padho.',
      );

  /// Paid batch: promo only (name + app link). No content link at all.
  static Future<void> paidBatch(BuildContext context, String title) => _send(
        context,
        '\u{1F393} $title',
        '$_appName app mein ye batch available hai. App download karke join karo.',
      );
}

/// Small share icon used in list tiles and app bars.
class ShareButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ShareButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.share_outlined, size: 20, color: Colors.white70),
      onPressed: onPressed,
    );
  }
}
