import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../data/notify_topics.dart';
import '../models/models.dart';
import 'app_monitor.dart';
import 'notify_prefs.dart';

/// Student ke chune hue EXAMS (notification topics) ka poora hisaab.
///
/// - Exam list data/notify_topics.dart (kExamTopics) se aati hai; topic ka
///   naam exam_bank_po, exam_ssc_cgl, exam_rrb_ntpc, exam_upsssc, exam_ahc_ro,
///   exam_uppsc hai.
/// - Choice phone mein (NotifyPrefs) aur Firestore (students/{uid}.exams)
///   dono mein save hoti hai, taaki naye phone par bhi wapas aa jaye.
/// - Har app start par topics dobara subscribe hote hain.
/// - Sab try/catch mein: offline ho to agli baar phir koshish hoti hai.
class ExamTopics {
  static const _kAsked = 'notif_exam_asked';

  /// Abhi chune hue exam topics (UI isse sun sakti hai).
  static final ValueNotifier<List<String>> mine = ValueNotifier<List<String>>(const []);

  static bool _isExam(String id) => kExamTopics.any((t) => t.id == id);

  /// Phone mein saved exam topics (list ke order mein).
  static Future<List<String>> load() async {
    final saved = await NotifyPrefs.load();
    final ids = kExamTopics.map((t) => t.id).where(saved.contains).toList();
    mine.value = ids;
    return ids;
  }

  static Future<void> _queue = Future<void>.value();

  /// Exams save karo + FCM topics badlo + Firestore mein likho.
  /// Tez-tez switch dabane par bhi calls ek ke baad ek chalti hain (aapas mein takrati nahi).
  static Future<void> setExams(List<String> ids, {bool syncCloud = true}) {
    final run = _queue.then((_) => _apply(ids, syncCloud));
    _queue = run.catchError((_) {});
    return run;
  }

  static Future<void> _apply(List<String> ids, bool syncCloud) async {
    final valid = kExamTopics.map((t) => t.id).where(ids.contains).toList();
    final old = await load();

    // Pehle choice yaad rakho (offline bhi na khoye), phir subscribe karne ki koshish.
    for (final t in old) {
      if (!valid.contains(t)) {
        await NotifyPrefs.remember(t, false);
        await NotifyPrefs.setTopic(t, false);
      }
    }
    for (final t in valid) {
      await NotifyPrefs.remember(t, true);
      if (!old.contains(t)) await NotifyPrefs.setTopic(t, true);
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAsked, true);
    } catch (_) {}
    mine.value = valid;

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

  /// Har app start par (main.dart ke _setupNotifications se): saved topics
  /// (exams + daily reminder) dobara subscribe.
  static Future<void> resubscribe() async {
    await NotifyPrefs.resubscribeSaved();
    final ids = await load();
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
        final ids = raw.map((e) => e.toString()).where(_isExam).toList();
        if (ids.isNotEmpty) await setExams(ids, syncCloud: false);
      }
    } catch (_) {}
  }

  /// Home khulne par: jisne abhi tak exam nahi chuna usse ek baar poochho.
  /// "Skip" dabane par dobara nahi poochhta (Profile / Notifications settings mein kabhi badal sakte hain).
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

  /// Notifications list: sabke liye wali + mere exam wali. Agar exam chuna
  /// hi nahi to sab dikhte hain.
  static List<NotificationModel> visibleTo(List<NotificationModel> all) {
    final ids = mine.value;
    if (ids.isEmpty) return all;
    return all.where((n) => n.topic.isEmpty || ids.contains(n.topic)).toList();
  }

  static Future<List<String>?> showPicker(BuildContext context, {List<String> initial = const []}) {
    final sel = initial.toSet();
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppC.card2,
          title: Text('Apna exam chuno / अपनी परीक्षा चुनें', style: TextStyle(color: AppC.text, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aapko usi exam ki notifications milengi. Ek se zyada chun sakte hain. / आपको उसी परीक्षा की नोटिफ़िकेशन मिलेंगी।',
                  style: TextStyle(color: AppC.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (final g in kExamTopics)
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
