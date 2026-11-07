import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/flashcard_data.dart';
import '../screens/exam_tracker_screen.dart';
import '../screens/gk_flash_quiz_screen.dart';
import '../screens/reasoning_drill_screen.dart';
import '../screens/score_journal_screen.dart';
import '../services/drill_store.dart';
import '../services/exam_tracker_store.dart';
import '../services/score_journal_store.dart';

/// Home ka "Exam Boost" card: Reasoning Drill, GK Flash Quiz, Exam Tracker, Score Journal.
/// Sab data phone me hai - Firestore se kuch nahi padhta / likhta.
class ExamBoostCard extends StatefulWidget {
  const ExamBoostCard({super.key});

  @override
  State<ExamBoostCard> createState() => _ExamBoostCardState();
}

class _ExamBoostCardState extends State<ExamBoostCard> {
  int _drillsToday = 0;
  ExamTrackSummary _exams = const ExamTrackSummary(0, '', 0, false);
  int _scoreCount = 0;
  int _scoreAvg = 0;

  @override
  void initState() {
    super.initState();
    DrillStore.changes.addListener(_reload);
    ExamTrackerStore.changes.addListener(_reload);
    ScoreJournalStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    DrillStore.changes.removeListener(_reload);
    ExamTrackerStore.changes.removeListener(_reload);
    ScoreJournalStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final today = await DrillStore.sessionsToday();
      final exams = await ExamTrackerStore.summary();
      final stats = await ScoreJournalStore.quickStats();
      if (!mounted) return;
      setState(() {
        _drillsToday = today;
        _exams = exams;
        _scoreCount = stats[0];
        _scoreAvg = stats[1];
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
    final drillSub = _drillsToday == 0
        ? 'Endless new questions\nअनगिनत नए सवाल'
        : 'Today: $_drillsToday drills\nआज: $_drillsToday ड्रिल';
    final gkSub = 'From ${kFlashcards.length} flashcards\n${kFlashcards.length} फ्लैशकार्ड से';
    String examSub;
    var examDot = false;
    if (_exams.count == 0) {
      examSub = 'Form & exam dates\nफॉर्म व परीक्षा तारीख़ें';
    } else if (_exams.hasNear) {
      final d = _exams.nearDays;
      final kindEn = _exams.nearIsForm ? 'form' : 'exam';
      final kindHi = _exams.nearIsForm ? 'फॉर्म' : 'परीक्षा';
      final whenEn = d == 0 ? 'today' : '${d}d left';
      final whenHi = d == 0 ? 'आज' : '$d दिन बाकी';
      examSub = '${_exams.nearName} $kindEn: $whenEn\n${_exams.nearName} $kindHi: $whenHi';
      examDot = _exams.nearIsForm && d <= 3;
    } else {
      examSub = '${_exams.count} tracked\n${_exams.count} ट्रैक हो रहे';
    }
    final scoreSub = _scoreCount == 0
        ? 'Log your test scores\nटेस्ट स्कोर लिखें'
        : 'Avg $_scoreAvg% • $_scoreCount tests\nऔसत $_scoreAvg% • $_scoreCount टेस्ट';
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
          Text('🎯 Exam Boost / परीक्षा बूस्ट', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('🧩', 'Reasoning Drill', drillSub, () => _open(const ReasoningDrillScreen())),
              const SizedBox(width: 10),
              _tile('⚡', 'GK Flash Quiz', gkSub, () => _open(const GkFlashQuizScreen())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('🗂️', 'Exam Tracker', examSub, () => _open(const ExamTrackerScreen()), dot: examDot),
              const SizedBox(width: 10),
              _tile('📓', 'Score Journal', scoreSub, () => _open(const ScoreJournalScreen())),
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
