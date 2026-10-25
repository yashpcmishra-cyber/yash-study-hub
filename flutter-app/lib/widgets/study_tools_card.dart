import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/flashcard_data.dart';
import '../screens/badges_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/revision_screen.dart';
import '../screens/study_timer_screen.dart';
import '../services/badge_store.dart';
import '../services/flashcard_store.dart';
import '../services/revision_store.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';

/// Home ka "Study Tools" card: Smart Revision, Study Timer, Flashcards, Badges.
/// Sab data phone me hai - Firestore se kuch nahi padhta / likhta.
class StudyToolsCard extends StatefulWidget {
  const StudyToolsCard({super.key});

  @override
  State<StudyToolsCard> createState() => _StudyToolsCardState();
}

class _StudyToolsCardState extends State<StudyToolsCard> {
  int _due = 0;
  int _totalMistakes = 0;
  int _todaySec = 0;
  int _known = 0;
  int _unlocked = 0;
  int _badgeTotal = 0;
  int _newBadges = 0;

  @override
  void initState() {
    super.initState();
    StudyStore.changes.addListener(_reload);
    StudyTimeStore.changes.addListener(_reload);
    FlashcardStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    StudyStore.changes.removeListener(_reload);
    StudyTimeStore.changes.removeListener(_reload);
    FlashcardStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final ov = await RevisionStore.overview();
      final sec = await StudyTimeStore.secondsOn(StudyStore.today());
      final known = await FlashcardStore.knownCount();
      final badges = await BadgeStore.evaluate();
      final fresh = await BadgeStore.newCount(badges);
      if (!mounted) return;
      setState(() {
        _due = ov.due;
        _totalMistakes = ov.total;
        _todaySec = sec;
        _known = known;
        _unlocked = badges.where((b) => b.unlocked).length;
        _badgeTotal = badges.length;
        _newBadges = fresh;
      });
    } catch (_) {
      // card chhupa nahi, bas purani values dikhti rahengi
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final revSub = _totalMistakes == 0
        ? 'No mistakes yet\nअभी कोई गलती नहीं'
        : (_due > 0 ? '$_due due today\nआज $_due बाकी' : 'All done today ✓\nआज का पूरा ✓');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppC.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppC.tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🛠️ Study Tools / स्टडी टूल्स', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('🔁', 'Smart Revision', revSub, () => _open(const RevisionScreen()), dot: _due > 0),
              const SizedBox(width: 10),
              _tile('⏱️', 'Study Timer', 'Today: ${StudyTimeStore.fmt(_todaySec)}\nआज: ${StudyTimeStore.fmt(_todaySec)}', () => _open(const StudyTimerScreen())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('🃏', 'Flashcards', '$_known / ${kFlashcards.length} learned\n$_known / ${kFlashcards.length} याद', () => _open(const FlashcardsScreen())),
              const SizedBox(width: 10),
              _tile('🏅', 'Badges', '$_unlocked / $_badgeTotal unlocked\n$_unlocked / $_badgeTotal खुले', () => _open(const BadgesScreen()), dot: _newBadges > 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(String emoji, String title, String sub, VoidCallback onTap, {bool dot = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 78,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, maxLines: 1, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ),
                        const SizedBox(height: 2),
                        Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text70, fontSize: 10.5, height: 1.25)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (dot)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppC.card2, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
