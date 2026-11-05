import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/notify_topics.dart';
import '../services/content_seen_store.dart';
import '../services/exam_topics.dart';
import '../services/firestore_service.dart';
import '../services/notify_prefs.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import '../app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _fs = FirestoreService();
  late final Stream<List<NotificationModel>> _stream = _fs.streamNotifications();
  int _markedMs = 0; // newest notification already marked as seen

  @override
  void initState() {
    super.initState();
    // Chune hue exams phone se padh lo (list unhi ke hisaab se filter hoti hai).
    ExamTopics.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Settings: kaun-se exam ki alerts chahiye + roz ka study reminder.
  Future<void> _openSettings() async {
    final saved = await NotifyPrefs.load();
    if (!mounted) return;
    final exams = <String>{for (final t in kExamTopics) if (saved.contains(t.id)) t.id};
    var daily = saved.contains(kDailyReminderTopic);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppC.card2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                Text('Notification settings / नोटिफ़िकेशन सेटिंग', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Aapko sirf chune hue exam ki alerts milengi. / आपको सिर्फ़ चुनी हुई परीक्षा की अलर्ट मिलेंगी।',
                  style: TextStyle(color: AppC.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (final g in kExamTopics)
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${g.emoji} ${g.en}', style: TextStyle(color: AppC.text, fontSize: 14)),
                    value: exams.contains(g.id),
                    onChanged: (v) {
                      setS(() {
                        if (v) {
                          exams.add(g.id);
                        } else {
                          exams.remove(g.id);
                        }
                      });
                      ExamTopics.setExams(exams.toList());
                    },
                  ),
                Divider(color: AppC.divider2),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('⏰ Daily study reminder (7 PM)', style: TextStyle(color: AppC.text, fontSize: 14)),
                  subtitle: Text('रोज़ शाम 7 बजे पढ़ाई की याद', style: TextStyle(color: AppC.muted, fontSize: 12)),
                  value: daily,
                  onChanged: (v) async {
                    final ok = await NotifyPrefs.setTopic(kDailyReminderTopic, v);
                    if (ok) {
                      setS(() => daily = v);
                    } else if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Internet check karke dobara try karein. / इंटरनेट जाँचकर फिर कोशिश करें।')));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {}); // list naye exam choice ke hisaab se dobara filter ho
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          // Sirf sabke liye wali + mere chune hue exam wali notifications.
          final items = ExamTopics.visibleTo(snap.data!);
          if (items.isEmpty) return const EmptyView('No notifications yet');
          // The student is looking at the list = these are seen
          // (clears the red dot on the Home bell). List is newest first.
          final newest = items.first.sentAt;
          if (newest != null && newest.millisecondsSinceEpoch != _markedMs) {
            _markedMs = newest.millisecondsSinceEpoch;
            WidgetsBinding.instance.addPostFrameCallback((_) => ContentSeenStore.markSeen('notif', newest));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              final tag = examLabelForTopic(n.topic);
              return DepthCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Text('🔔', style: TextStyle(fontSize: 22)),
                  title: Text(n.title, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tag != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('🎯 $tag', style: TextStyle(color: AppC.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      Text(n.body, style: TextStyle(color: AppC.muted)),
                    ],
                  ),
                  trailing: n.sentAt != null ? Text(DateFormat('d MMM').format(n.sentAt!), style: TextStyle(color: AppC.muted, fontSize: 10)) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
