import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../screens/speed_math_screen.dart';
import '../screens/study_planner_screen.dart';
import '../screens/syllabus_screen.dart';
import '../screens/weekly_report_screen.dart';
import '../services/plan_service.dart';
import '../services/speed_math_store.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';
import '../services/syllabus_store.dart';
import '../services/weekly_report_service.dart';

/// Home ka "Smart Study" card: Today's Plan, Speed Maths, Syllabus, Weekly Report.
/// Sab data phone me hai - Firestore se kuch nahi padhta / likhta.
class SmartStudyCard extends StatefulWidget {
  const SmartStudyCard({super.key});

  @override
  State<SmartStudyCard> createState() => _SmartStudyCardState();
}

class _SmartStudyCardState extends State<SmartStudyCard> {
  int _planDone = 0;
  int _planTotal = 0;
  int _speedToday = 0;
  bool _hasSyllabus = false;
  int _sylPercent = 0;
  int _weekScore = 0;
  String _weekEmoji = '🌱';

  @override
  void initState() {
    super.initState();
    StudyStore.changes.addListener(_reload);
    StudyTimeStore.changes.addListener(_reload);
    SyllabusStore.changes.addListener(_reload);
    SpeedMathStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    StudyStore.changes.removeListener(_reload);
    StudyTimeStore.changes.removeListener(_reload);
    SyllabusStore.changes.removeListener(_reload);
    SpeedMathStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final plan = await PlanService.build();
      final speed = await SpeedMathStore.roundsOn(StudyStore.today());
      final exam = await SyllabusStore.selectedExam();
      var pct = 0;
      if (exam != null && exam.totalTopics > 0) {
        final done = SyllabusStore.doneCount(exam, await SyllabusStore.doneMap());
        pct = (done * 100 / exam.totalTopics).round();
      }
      final week = await WeeklyReportService.build();
      if (!mounted) return;
      setState(() {
        _planDone = plan.doneCount;
        _planTotal = plan.total;
        _speedToday = speed;
        _hasSyllabus = exam != null;
        _sylPercent = pct;
        _weekScore = week.score;
        _weekEmoji = week.emoji;
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
    final planComplete = _planTotal > 0 && _planDone >= _planTotal;
    final planSub = _planTotal == 0
        ? 'Plan for today\nआज का प्लान'
        : (planComplete ? 'All done ✓\nसब पूरा ✓' : '$_planDone / $_planTotal done\n$_planDone / $_planTotal पूरे');
    final speedSub = 'Today: $_speedToday rounds\nआज: $_speedToday राउंड';
    final sylSub = _hasSyllabus ? '$_sylPercent% done\n$_sylPercent% पूरा' : 'Pick your exam\nपरीक्षा चुनें';
    final weekSub = 'Score $_weekScore $_weekEmoji\nस्कोर $_weekScore $_weekEmoji';
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
          Text('🚀 Smart Study / स्मार्ट स्टडी', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('📅', "Today's Plan", planSub, () => _open(const StudyPlannerScreen()), dot: _planTotal > 0 && !planComplete),
              const SizedBox(width: 10),
              _tile('⚡', 'Speed Maths', speedSub, () => _open(const SpeedMathScreen())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('📚', 'Syllabus', sylSub, () => _open(const SyllabusScreen())),
              const SizedBox(width: 10),
              _tile('📈', 'Weekly Report', weekSub, () => _open(const WeeklyReportScreen())),
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
