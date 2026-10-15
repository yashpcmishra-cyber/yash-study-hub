import 'package:flutter/material.dart';
import '../services/study_store.dart';

const _navy = Color(0xFF081136);
const _tileBg = Color(0xFF080E2A);
const _cardBg = Color(0xFF101D57);
const _gold = Color(0xFFFFFF29);

/// Home screen ka "Study Corner": 7-din streak, exam countdown aur daily goal.
/// (Daily Quiz / Notebook / Progress ke tiles Home ke grid me hain.)
/// Sab data phone me hai - Firestore se kuch nahi padhta.
class StudyCornerCard extends StatefulWidget {
  const StudyCornerCard({super.key});

  @override
  State<StudyCornerCard> createState() => _StudyCornerCardState();
}

class _StudyCornerCardState extends State<StudyCornerCard> {
  StreakInfo _streak = const StreakInfo(0);
  ExamTarget _exam = const ExamTarget('', null);
  int _goal = StudyStore.defaultGoal;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    StudyStore.changes.addListener(_reload);
    _init();
  }

  @override
  void dispose() {
    StudyStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await StudyStore.touchToday(); // aaj ka din streak me gino
    } catch (_) {}
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final s = await StudyStore.readStreak();
      final e = await StudyStore.readExam();
      final g = await StudyStore.goalTarget();
      final d = await StudyStore.goalDoneToday();
      if (!mounted) return;
      setState(() {
        _streak = s;
        _exam = e;
        _goal = g;
        _done = d;
      });
    } catch (_) {
      // card chhupa nahi, bas purani values dikhti rahengi
    }
  }

  // ------------------------------------------------------------- exam dialog

  Future<void> _editExam() async {
    final nameCtrl = TextEditingController(text: _exam.name);
    DateTime? picked = _exam.date;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Exam countdown / परीक्षा काउंटडाउन', style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                maxLength: 30,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Exam name (e.g. SSC CGL) / परीक्षा का नाम',
                  labelStyle: TextStyle(color: Colors.white60),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(picked == null ? 'Pick exam date / परीक्षा की तारीख चुनें' : _fmt(picked!)),
                onPressed: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: (picked != null && !picked!.isBefore(today)) ? picked! : today.add(const Duration(days: 30)),
                    firstDate: today,
                    lastDate: today.add(const Duration(days: 365 * 3)),
                  );
                  if (d != null) setLocal(() => picked = DateTime(d.year, d.month, d.day));
                },
              ),
            ],
          ),
          actions: [
            if (_exam.isSet) TextButton(onPressed: () => Navigator.of(ctx).pop('clear'), child: const Text('Remove / हटाएँ', style: TextStyle(color: Colors.redAccent))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop('save'), child: const Text('Save')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    if (action == 'clear') {
      await StudyStore.clearExam();
    } else if (action == 'save') {
      final d = picked;
      if (d == null) {
        _toast('Pick the exam date first. / पहले परीक्षा की तारीख चुनें।');
        return;
      }
      await StudyStore.saveExam(name.isEmpty ? 'Exam' : name, d);
    }
  }

  static String _fmt(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------- goal dialog

  Future<void> _editGoal() async {
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: _cardBg,
        title: const Text('Daily goal (questions) / रोज़ का लक्ष्य (सवाल)', style: TextStyle(color: Colors.white, fontSize: 17)),
        children: [
          for (final n in const [10, 20, 30, 50, 100])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(n),
              child: Text('$n questions per day / $n सवाल प्रतिदिन${n == _goal ? '  ✓' : ''}', style: TextStyle(color: n == _goal ? _gold : Colors.white, fontSize: 15)),
            ),
        ],
      ),
    );
    if (v != null) await StudyStore.setGoalTarget(v);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FFE81F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _streakRow(),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _examTile()),
                const SizedBox(width: 10),
                Expanded(child: _goalTile()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakRow() {
    final s = _streak;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.justCompleted ? '7-day streak complete! 🎉 / 7 दिन की स्ट्रीक पूरी!' : '7-Day Streak / 7 दिन की स्ट्रीक',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            if (s.completedWeeks > 0)
              Text('🏆 x${s.completedWeeks}', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 12.5)),
            const SizedBox(width: 8),
            Text('${s.filled}/7', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: Container(
                  height: 26,
                  margin: EdgeInsets.only(right: i == 7 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: i <= s.filled ? _gold : _navy,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: i <= s.filled ? _gold : Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: i <= s.filled
                      ? const Icon(Icons.check, size: 16, color: _navy)
                      : Text('$i', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _examTile() {
    final e = _exam;
    final left = e.daysLeft();
    final String big;
    final String small;
    if (!e.isSet) {
      big = '🎯';
      small = 'Set exam date\nपरीक्षा की तारीख चुनें';
    } else if (left < 0) {
      big = '✅';
      small = '${e.name} is over\nनई तारीख चुनें';
    } else if (left == 0) {
      big = 'Today!';
      small = '${e.name} • आज';
    } else {
      big = '$left';
      small = '${e.name}\ndays left / दिन बाकी';
    }
    return GestureDetector(
      onTap: _editExam,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(big, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 28))),
            const SizedBox(height: 2),
            Text(small, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _goalTile() {
    final ratio = _goal <= 0 ? 0.0 : (_done / _goal).clamp(0.0, 1.0).toDouble();
    final reached = _done >= _goal;
    return GestureDetector(
      onTap: _editGoal,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 5,
                      backgroundColor: Colors.white12,
                      color: reached ? Colors.greenAccent : _gold,
                    ),
                  ),
                  Text(reached ? '🎉' : '${(ratio * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today\u2019s goal / आज का लक्ष्य', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('$_done / $_goal Qs / सवाल', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
