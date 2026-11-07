import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/models.dart';
import '../services/drill_store.dart';
import '../services/reasoning_generator.dart';
import '../services/study_store.dart';
import 'quiz_session_screen.dart';

/// Reasoning Drill: 7 tarah ke reasoning sawal (series, coding, calendar, clock,
/// ranking, direction ...) jo har baar naye bante hain - kabhi khatam nahi hote.
/// Sawal phone me hi bante hain: 0 internet, Firestore ko 0 reads / 0 writes.
/// Galat sawal Smart Revision (Mistake Notebook) me chale jaate hain.
class ReasoningDrillScreen extends StatefulWidget {
  const ReasoningDrillScreen({super.key});

  @override
  State<ReasoningDrillScreen> createState() => _ReasoningDrillScreenState();
}

class _ReasoningDrillScreenState extends State<ReasoningDrillScreen> {
  static const int _count = 10;
  Map<String, DrillBest> _best = <String, DrillBest>{};
  int _sessions = 0;
  int _today = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await DrillStore.allBest();
      final s = await DrillStore.sessions();
      final t = await DrillStore.sessionsToday();
      if (!mounted) return;
      setState(() {
        _best = b;
        _sessions = s;
        _today = t;
      });
    } catch (_) {
      // purani values dikhti rahengi
    }
  }

  Future<void> _start(String type, String title) async {
    final qs = ReasoningGenerator.generate(type, _count);
    if (qs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not make questions. Try again. / सवाल नहीं बन सके। दोबारा कोशिश करें।')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: title,
        questions: qs,
        onFinished: (answers) => _finish(type, title, qs, answers),
      ),
    ));
    if (mounted) _load();
  }

  Future<void> _finish(String type, String title, List<MockQuestion> qs, List<int?> answers) async {
    final wrong = <MockQuestion>[];
    var answered = 0;
    var correct = 0;
    for (var i = 0; i < qs.length; i++) {
      final a = i < answers.length ? answers[i] : null;
      if (a == null) continue;
      answered++;
      if (a == qs[i].correctIndex) {
        correct++;
      } else {
        wrong.add(qs[i]);
      }
    }
    try {
      await StudyStore.addMistakes(wrong, subject: 'Reasoning', source: title);
      // Generated sawal kabhi khatam nahi hote, isliye goal me aadhe gine jaate hain.
      await StudyStore.addGoalProgress(answered ~/ 2);
      await DrillStore.record(type: type, correct: correct, answered: answered, total: qs.length);
    } catch (_) {
      // hisaab na bane to bhi quiz ka natija nahi rukna chahiye
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reasoning Drill / रीज़निंग ड्रिल')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppC.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppC.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fresh questions every time — the set never repeats.\nहर बार नए सवाल — सेट कभी दोहराता नहीं।',
                  style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'Drills done: $_sessions  •  Today: $_today\nकुल ड्रिल: $_sessions  •  आज: $_today',
                  style: TextStyle(color: AppC.text54, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _start('mix', 'Mixed Reasoning / मिक्स रीज़निंग'),
              icon: const Icon(Icons.shuffle),
              label: const Text('Mixed Drill — 10 questions / मिक्स ड्रिल'),
            ),
          ),
          const SizedBox(height: 14),
          Text('Pick a topic / टॉपिक चुनें', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          for (final t in kReasoningTypes) _typeCard(t),
        ],
      ),
    );
  }

  Widget _typeCard(ReasoningType t) {
    final b = _best[t.id];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _start(t.id, '${t.en} / ${t.hi}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppC.line),
        ),
        child: Row(
          children: [
            Text(t.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.en} / ${t.hi}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(t.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text54, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: b == null ? AppC.chip : AppC.greenWash, borderRadius: BorderRadius.circular(20)),
              child: Text(
                b == null ? 'New' : 'Best ${b.percent}%',
                style: TextStyle(color: b == null ? AppC.text70 : AppC.green, fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
