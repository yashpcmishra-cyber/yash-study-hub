import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Official social links (used by the Home rotating card and Profile > Contact and Join Us).
const String kInstagramUrl = 'https://www.instagram.com/yash_study_hub';
const String kFacebookUrl = 'https://www.facebook.com/YashStudyHub';

void _showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Opens a web link (Drive, YouTube, Telegram, news...) in the phone's
/// browser/app. Never throws — shows a small message if the link is bad.
Future<bool> openExternalLink(BuildContext context, String? rawUrl) async {
  final text = (rawUrl ?? '').trim();
  final uri = Uri.tryParse(text);
  if (text.isEmpty || uri == null || !uri.hasScheme) {
    _showSnack(context, 'This link is not valid.');
    return false;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showSnack(context, 'Could not open this link.');
    return ok;
  } catch (_) {
    _showSnack(context, 'Could not open this link.');
    return false;
  }
}
