import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/flashcard_data.dart';
import '../screens/badges_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/study_timer_screen.dart';
import '../services/badge_store.dart';
import '../services/flashcard_store.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';
import '../services/study_timer_service.dart';

/// Home ka "Study Tools" card: Flashcards, Badges.
/// Sab data phone me hai - Firestore se kuch nahi padhta / likhta.
class StudyToolsCard extends StatefulWidget {
  const StudyToolsCard({super.key});

  @override
  State<StudyToolsCard> createState() => _StudyToolsCardState();
}

class _StudyToolsCardState extends State<StudyToolsCard> {
  int _known = 0;
  int _unlocked = 0;
  int _badgeTotal = 0;
  int _newBadges = 0;
  int _todayStudySec = 0;

  @override
  void initState() {
    super.initState();
    StudyStore.changes.addListener(_reload);
    FlashcardStore.changes.addListener(_reload);
    StudyTimeStore.changes.addListener(_reload);
    StudyTimerService.instance.addListener(_onTimer);
    StudyTimerService.instance.init();
    _reload();
  }

  @override
  void dispose() {
    StudyStore.changes.removeListener(_reload);
    FlashcardStore.changes.removeListener(_reload);
    StudyTimeStore.changes.removeListener(_reload);
    StudyTimerService.instance.removeListener(_onTimer);
    super.dispose();
  }

  // Timer chalte / ruke to tile ka text badle.
  void _onTimer() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    try {
      final today = await StudyTimeStore.secondsOn(StudyStore.today());
      final known = await FlashcardStore.knownCount();
      final badges = await BadgeStore.evaluate();
      final fresh = await BadgeStore.newCount(badges);
      if (!mounted) return;
      setState(() {
        _known = known;
        _unlocked = badges.where((b) => b.unlocked).length;
        _badgeTotal = badges.length;
        _newBadges = fresh;
        _todayStudySec = today;
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
    final timer = StudyTimerService.instance;
    final String timerSub;
    if (timer.running) {
      final m = (timer.remainSec / 60).ceil();
      timerSub = timer.isBreak ? 'Break running • $m min left\nब्रेक चालू • $m मिनट बाकी' : 'Running • $m min left\nचालू • $m मिनट बाकी';
    } else {
      final t = StudyTimeStore.fmt(_todayStudySec);
      timerSub = 'Today: $t\nआज: $t';
    }
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
              _tile('🃏', 'Flashcards', '$_known / ${kFlashcards.length} learned\n$_known / ${kFlashcards.length} याद', () => _open(const FlashcardsScreen())),
              const SizedBox(width: 10),
              _tile('🏅', 'Badges', '$_unlocked / $_badgeTotal unlocked\n$_unlocked / $_badgeTotal खुले', () => _open(const BadgesScreen()), dot: _newBadges > 0),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('⏱️', 'Study Timer', timerSub, () => _open(const StudyTimerScreen()), dot: timer.running),
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
