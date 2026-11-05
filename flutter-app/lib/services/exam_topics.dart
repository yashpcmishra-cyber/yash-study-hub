import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../models/models.dart';
import 'app_monitor.dart';

/// Notification ke liye exam groups. `id` hi FCM topic (exam_<id>) aur
/// notification ke `audience` field mein jaata hai - isse badla nahi jaata.
class ExamGroup {
  final String id;
  final String emoji;
  final String en;
  final String hi;
  const ExamGroup(this.id, this.emoji, this.en, this.hi);
  String get topic => 'exam_$id';
}

const List<ExamGroup> kExamGroups = [
  ExamGroup('ssc', '🧾', 'SSC', 'एसएससी'),
  ExamGroup('banking', '🏦', 'Banking', 'बैंकिंग'),
  ExamGroup('railway', '🚆', 'Railway', 'रेलवे'),
  ExamGroup('up', '📋', 'UP (UPSSSC / UPPSC / AHC RO)', 'यूपी (UPSSSC / UPPSC / AHC RO)'),
];

/// Student ke chune hue exams ke FCM topics ka poora hisaab.
///
/// - Choice phone mein (SharedPreferences) aur Firestore (students/{uid}.exams)
///   dono mein save hoti hai, taaki naye phone par bhi wapas aa jaye.
/// - Har launch par topics dobara subscribe hote hain (FCM token badalne par
///   subscription kabhi-kabhi chhoot jaati hai).
/// - Sab try/catch mein: offline ho to agli baar phir koshish hoti hai.
class ExamTopics {
  static const _kIds = 'notif_exam_ids';
  static const _kAsked = 'notif_exam_asked';

  /// Abhi chune hue exams (UI isse sun sakti hai).
  static final ValueNotifier<List<String>> mine = ValueNotifier<List<String>>(const []);

  static bool _known(String id) => kExamGroups.any((g) => g.id == id);

  static Future<List<String>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ids = (p.getStringList(_kIds) ?? const <String>[]).where(_known).toList();
      mine.value = ids;
      return ids;
    } catch (_) {
      return mine.value;
    }
  }

  /// Choice save karo + topics badlo + Firestore mein likho.
  static Future<void> setExams(List<String> ids, {bool syncCloud = true}) async {
    final valid = ids.where(_known).toSet().toList();
    List<String> old = const [];
    try {
      final p = await SharedPreferences.getInstance();
      old = p.getStringList(_kIds) ?? const <String>[];
      await p.setStringList(_kIds, valid);
      await p.setBool(_kAsked, true);
    } catch (_) {}
    mine.value = valid;

    try {
      final m = FirebaseMessaging.instance;
      for (final id in old) {
        if (!valid.contains(id)) await m.unsubscribeFromTopic('exam_$id');
      }
      for (final id in valid) {
        await m.subscribeToTopic('exam_$id');
      }
    } catch (_) {
      // Offline: resubscribe() agli baar kar dega.
    }

    AppMonitor.setExams(valid);
    AppMonitor.event('exam_selected', {'exams': valid.isEmpty ? 'none' : valid.join(',')});
    if (syncCloud) await _saveCloud(valid);
  }

  static Future<void> _saveCloud(List<String> ids) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .set({'exams': ids}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Har launch par (main.dart ke _setupNotifications se).
  static Future<void> resubscribe() async {
    final ids = await load();
    try {
      final m = FirebaseMessaging.instance;
      for (final id in ids) {
        await m.subscribeToTopic('exam_$id');
      }
    } catch (_) {}
    AppMonitor.setExams(ids);
  }

  /// Naye phone / reinstall: Firestore mein jo exams save the unhe wapas lao.
  static Future<void> restoreFromCloud() async {
    if (mine.value.isNotEmpty) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('students').doc(uid).get().timeout(const Duration(seconds: 10));
      final raw = doc.data()?['exams'];
      if (raw is List) {
        final ids = raw.map((e) => e.toString()).where(_known).toList();
        if (ids.isNotEmpty) await setExams(ids, syncCloud: false);
      }
    } catch (_) {}
  }

  /// Home khulne par: jisne abhi tak exam nahi chuna usse ek baar poochho.
  /// "Skip" dabane par dobara nahi poochhta (Profile mein kabhi bhi badal sakte hain).
  static Future<void> askIfNeeded(BuildContext context) async {
    await load();
    if (mine.value.isNotEmpty) return;
    await restoreFromCloud();
    if (mine.value.isNotEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_kAsked) == true) return;
      if (!context.mounted) return;
      final picked = await showPicker(context);
      if (picked == null) {
        await p.setBool(_kAsked, true);
        return;
      }
      await setExams(picked);
    } catch (_) {}
  }

  /// Notifications list: sabke liye wale + mere exam wale. Agar exam chuna
  /// hi nahi to sab dikhte hain.
  static List<NotificationModel> visibleTo(List<NotificationModel> all) {
    final ids = mine.value;
    if (ids.isEmpty) return all;
    return all.where((n) => n.audience == 'all' || n.audience.isEmpty || ids.contains(n.audience)).toList();
  }

  static Future<List<String>?> showPicker(BuildContext context, {List<String> initial = const []}) {
    final sel = initial.toSet();
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppC.card2,
          title: Text('Apna exam chuno / अपनी परीक्षा चुनें', style: TextStyle(color: AppC.text, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aapko usi exam ki notifications milengi. Ek se zyada chun sakte hain. / आपको उसी परीक्षा की नोटिफ़िकेशन मिलेंगी।',
                style: TextStyle(color: AppC.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final g in kExamGroups)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppC.gold,
                  value: sel.contains(g.id),
                  onChanged: (v) => setS(() {
                    if (v == true) {
                      sel.add(g.id);
                    } else {
                      sel.remove(g.id);
                    }
                  }),
                  title: Text('${g.emoji} ${g.en}', style: TextStyle(color: AppC.text, fontSize: 14)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Skip')),
            ElevatedButton(
              onPressed: sel.isEmpty ? null : () => Navigator.of(ctx).pop(sel.toList()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
