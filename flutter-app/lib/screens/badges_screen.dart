import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/badge_store.dart';
import '../services/share_service.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';
import '../widgets/state_views.dart';

/// Badges / Achievements: streak, sawal, tests, study time, revision, flashcards
/// se khulte hain. Share button se progress WhatsApp / Telegram par bhej sakte hain.
/// Data sirf phone me hai - Firestore ko 0 reads / 0 writes.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  List<BadgeInfo>? _badges;
  Set<String> _seenBefore = <String>{};
  LifetimeStats _life = const LifetimeStats();
  int _focusSec = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await BadgeStore.evaluate();
      final seen = await BadgeStore.seenIds();
      final life = await StudyStore.lifetime();
      final focus = await StudyTimeStore.totalSeconds();
      await BadgeStore.markSeen(all); // ab ye sab dekh liye gaye
      if (!mounted) return;
      setState(() {
        _badges = all;
        _seenBefore = seen;
        _life = life;
        _focusSec = focus;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _badges = const <BadgeInfo>[]);
    }
  }

  void _share(int unlocked, int total) {
    final line = '🔥 Best streak: ${_life.maxStreak} days\n'
        '🎯 Questions solved: ${_life.questions}\n'
        '📝 Tests & quizzes: ${_life.tests}\n'
        '⏱️ Study time: ${StudyTimeStore.fmt(_focusSec)}\n'
        '🏅 Badges: $unlocked/$total (${BadgeStore.level(unlocked)})';
    ShareService.custom(context, '🏅 My progress on Yash Study Hub / मेरी प्रोग्रेस', line);
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badges;
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: badges == null ? const LoadingView() : _content(badges),
    );
  }

  Widget _content(List<BadgeInfo> badges) {
    final unlocked = badges.where((b) => b.unlocked).length;
    final total = badges.length;
    // Khule hue badge pehle, phir baaki (jo zyada paas hain wo upar).
    final sorted = List<BadgeInfo>.from(badges)
      ..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        return b.ratio.compareTo(a.ratio);
      });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('$unlocked / $total', style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 38)),
              const Text('Badges unlocked / बैज खुले', style: TextStyle(color: AppC.onGold, fontSize: 13)),
              const SizedBox(height: 8),
              Text('Level: ${BadgeStore.level(unlocked)}', style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => _share(unlocked, total),
          icon: const Icon(Icons.share),
          label: const Text('Share my progress / प्रोग्रेस शेयर करें'),
        ),
        const SizedBox(height: 14),
        for (final b in sorted) _tile(b),
        const SizedBox(height: 6),
        Text(
          'Badges are calculated on your phone.\nबैज आपके फ़ोन के डेटा से बनते हैं।',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppC.muted, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _tile(BadgeInfo b) {
    final isNew = b.unlocked && !_seenBefore.contains(b.id);
    final cur = b.current > b.target ? b.target : b.current;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppC.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: b.unlocked ? AppC.accent : Colors.transparent, width: 1.2),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: b.unlocked ? 1 : 0.35,
            child: Text(b.emoji, style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${b.title} / ${b.titleHi}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: b.unlocked ? AppC.text : AppC.text70, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (isNew)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${b.desc}\n${b.descHi}', style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.3)),
                const SizedBox(height: 6),
                if (b.unlocked)
                  Text('✓ Unlocked / खुल गया', style: TextStyle(color: AppC.green, fontWeight: FontWeight.w600, fontSize: 12))
                else
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: b.ratio, minHeight: 6, backgroundColor: AppC.card, color: AppC.accent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$cur / ${b.target}', style: TextStyle(color: AppC.text70, fontSize: 11.5)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
