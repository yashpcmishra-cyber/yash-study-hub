import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/xp_store.dart';

/// Home ka XP / Level bar (Study Corner ke andar). Sab data phone me hai -
/// Firestore se kuch nahi padhta. Dabane par "XP kaise milta hai" dikhta hai.
class XpCard extends StatefulWidget {
  const XpCard({super.key});

  @override
  State<XpCard> createState() => _XpCardState();
}

class _XpCardState extends State<XpCard> {
  XpInfo? _info;

  @override
  void initState() {
    super.initState();
    XpStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    XpStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final i = await XpStore.info();
      if (!mounted) return;
      setState(() => _info = i);
    } catch (_) {
      // purani value dikhti rahegi
    }
  }

  void _showHow() {
    const rows = <List<String>>[
      ['❓', 'Each question answered / हर सवाल', '+2'],
      ['📝', 'Finish a Mock Test / मॉक टेस्ट पूरा', '+20 (80%+ → +30)'],
      ['📰', 'Daily Quiz / डेली क्विज़', '+15'],
      ['🎯', 'Daily goal done / रोज़ का लक्ष्य पूरा', '+25'],
      ['🔥', 'Streak day / स्ट्रीक का दिन', '+11 … +40'],
      ['🔁', 'Fix a mistake / गलती सुधारी', '+5'],
      ['⚡', 'Speed Maths round / राउंड', '+5'],
      ['📚', 'Syllabus topic done / टॉपिक पूरा', '+3'],
      ['⏱️', 'Study Timer / स्टडी टाइमर', '+1 / min'],
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card2,
        title: Text('How to earn XP / XP कैसे मिलता है', style: TextStyle(color: AppC.text, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(r[0], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r[1], style: TextStyle(color: AppC.text, fontSize: 12.5))),
                    const SizedBox(width: 6),
                    Text(r[2], style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
              const SizedBox(height: 8),
              Text(
                'Level 2 = 100 XP, Level 3 = 300 XP, Level 4 = 600 XP ... The more you study, the higher you go!\nलेवल 2 = 100 XP, लेवल 3 = 300 XP, लेवल 4 = 600 XP ... जितना पढ़ोगे, उतना ऊपर जाओगे!',
                style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    if (i == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _showHow,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('LVL', style: TextStyle(color: AppC.onGold, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  Text('${i.level}', style: const TextStyle(color: AppC.onGold, fontSize: 18, fontWeight: FontWeight.bold, height: 1.0)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('⭐ ${i.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text('${i.intoLevel} / ${i.forLevel} XP', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: i.ratio, minHeight: 7, backgroundColor: AppC.card, color: AppC.gold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Today +${i.today} XP  •  ${i.toNext} XP to Level ${i.level + 1}\nआज +${i.today} XP  •  लेवल ${i.level + 1} के लिए ${i.toNext} XP',
                    style: TextStyle(color: AppC.text70, fontSize: 10.5, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
