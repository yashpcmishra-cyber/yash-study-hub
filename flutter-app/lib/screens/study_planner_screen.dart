import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/plan_service.dart';
import '../services/speed_math_store.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';
import '../services/syllabus_store.dart';
import '../widgets/state_views.dart';
import 'daily_quiz_screen.dart';
import 'free_mcqs_screen.dart';
import 'revision_screen.dart';
import 'speed_math_screen.dart';
import 'study_timer_screen.dart';
import 'syllabus_screen.dart';

/// Aaj ka Plan: phone ke data se roz ke kaam apne aap bante hain, aur jaise-jaise
/// student padhta hai, tick hote jaate hain. Kuch alag save nahi hota -
/// Firestore ko 0 reads / 0 writes.
class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  PlanSummary? _plan;
  StreakInfo _streak = const StreakInfo(0);

  @override
  void initState() {
    super.initState();
    StudyStore.changes.addListener(_load);
    StudyTimeStore.changes.addListener(_load);
    SyllabusStore.changes.addListener(_load);
    SpeedMathStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    StudyStore.changes.removeListener(_load);
    StudyTimeStore.changes.removeListener(_load);
    SyllabusStore.changes.removeListener(_load);
    SpeedMathStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final plan = await PlanService.build();
      final streak = await StudyStore.readStreak();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _streak = streak;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _plan ??= const PlanSummary(<PlanTask>[], -1, '', 60));
    }
  }

  Widget? _screenFor(String id) {
    switch (id) {
      case 'quiz':
        return const DailyQuizScreen();
      case 'revision':
        return const RevisionScreen();
      case 'goal':
        return const FreeMcqsScreen();
      case 'focus':
        return const StudyTimerScreen();
      case 'syllabus':
        return const SyllabusScreen();
      case 'speed':
        return const SpeedMathScreen();
    }
    return null;
  }

  Future<void> _open(PlanTask t) async {
    final screen = _screenFor(t.id);
    if (screen == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Plan")),
      body: plan == null
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(plan),
                  const SizedBox(height: 14),
                  for (final t in plan.tasks) _taskTile(t),
                  const SizedBox(height: 6),
                  Text(
                    'Tasks tick automatically as you study. The plan resets every day.\nपढ़ाई करते ही टास्क अपने आप टिक हो जाते हैं। प्लान रोज़ नया बनता है।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
    );
  }

  String _message(PlanSummary p) {
    if (p.complete) return "🎉 Today's plan is complete! Great job.\n🎉 आज का प्लान पूरा! शाबाश।";
    final left = p.total - p.doneCount;
    if (p.doneCount == 0) return "Let's start with one small task.\nचलिए, एक छोटे टास्क से शुरुआत करें।";
    return '$left more to go — you are doing well!\nबस $left और बाकी — बढ़िया चल रहा है!';
  }

  Widget _header(PlanSummary p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: p.ratio.clamp(0.0, 1.0).toDouble(),
                        strokeWidth: 8,
                        backgroundColor: AppC.line,
                        color: p.complete ? AppC.green : AppC.gold,
                      ),
                    ),
                    Text('${p.doneCount}/${p.total}', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(_message(p), style: TextStyle(color: AppC.text, fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill('🔥 ${_streak.days} day streak / दिन'),
              if (p.daysLeft >= 0) _pill('📅 ${p.daysLeft} days to ${p.examName.isEmpty ? 'exam' : p.examName}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppC.panel, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: AppC.textSoft, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _taskTile(PlanTask t) {
    return GestureDetector(
      onTap: () => _open(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.done ? AppC.greenWash : AppC.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.done ? AppC.green : AppC.line),
        ),
        child: Row(
          children: [
            Text(t.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.title} / ${t.titleHi}', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(t.sub, style: TextStyle(color: AppC.text70, fontSize: 12)),
                  Text(t.subHi, style: TextStyle(color: AppC.text54, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              t.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: t.done ? AppC.green : AppC.text38,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
