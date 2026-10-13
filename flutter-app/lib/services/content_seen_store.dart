import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Last time the admin added something new" for each Home grid.
///
/// The admin side writes these 4 timestamps into the existing document
/// appConfig/main (merge) every time something NEW is uploaded:
///   newPdfsAt     - new free PDF
///   newMocksAt    - new free mock test
///   newVideosAt   - new free video (hand-uploaded, NOT the auto YouTube fetch)
///   newBatchesAt  - new paid batch, or new PDF / video / mock inside a batch
/// A missing field = epoch 0 = "nothing yet".
class ContentUpdates {
  final DateTime pdfs;
  final DateTime mocks;
  final DateTime videos;
  final DateTime batches;

  const ContentUpdates({
    required this.pdfs,
    required this.mocks,
    required this.videos,
    required this.batches,
  });

  static final DateTime _none = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime _ts(dynamic v) => v is Timestamp ? v.toDate() : _none;

  factory ContentUpdates.fromMap(Map<String, dynamic>? m) => ContentUpdates(
        pdfs: _ts(m?['newPdfsAt']),
        mocks: _ts(m?['newMocksAt']),
        videos: _ts(m?['newVideosAt']),
        batches: _ts(m?['newBatchesAt']),
      );

  DateTime forKey(String key) {
    switch (key) {
      case 'pdfs':
        return pdfs;
      case 'mocks':
        return mocks;
      case 'videos':
        return videos;
      case 'batches':
        return batches;
      default:
        return _none;
    }
  }
}

/// Remembers (on THIS phone only) up to which time the student has already
/// seen each red-dot item: 'notif' (bell), 'pdfs', 'mocks', 'videos',
/// 'batches'. Nothing is written to Firebase.
///
/// A dot shows when the newest item is NEWER than the saved time, and it
/// disappears when the student opens that screen (markSeen).
///
/// First run on a phone (nothing saved yet) = the current newest item is
/// simply remembered, so a fresh install / first update never shows dots for
/// old content.
class ContentSeenStore {
  static const _prefix = 'seen_ts_';
  static const _keys = ['notif', 'pdfs', 'mocks', 'videos', 'batches'];

  /// null = not loaded yet. Home listens to this to redraw the dots.
  static final ValueNotifier<Map<String, int>?> seen = ValueNotifier<Map<String, int>?>(null);

  static Future<void> load() async {
    if (seen.value != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = <String, int>{};
      for (final k in _keys) {
        final v = prefs.getInt('$_prefix$k');
        if (v != null) m[k] = v;
      }
      seen.value ??= m;
    } catch (_) {
      seen.value ??= <String, int>{};
    }
  }

  /// Student has seen everything up to [latest] for [key].
  static Future<void> markSeen(String key, DateTime latest) async {
    await load();
    final ms = latest.millisecondsSinceEpoch;
    final cur = seen.value ?? <String, int>{};
    final saved = cur[key];
    if (saved != null && saved >= ms) return;
    seen.value = {...cur, key: ms};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefix$key', ms);
    } catch (_) {
      // not critical - the dot would just show once more
    }
  }

  /// true = show the red dot. [latest] == null means "not loaded from
  /// Firebase yet" and never shows a dot.
  static bool unread(String key, DateTime? latest) {
    final m = seen.value;
    if (m == null || latest == null) return false;
    final saved = m[key];
    if (saved == null) {
      // First time on this phone: remember what is already there.
      WidgetsBinding.instance.addPostFrameCallback((_) => markSeen(key, latest));
      return false;
    }
    return latest.millisecondsSinceEpoch > saved;
  }
}
