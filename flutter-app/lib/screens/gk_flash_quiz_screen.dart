import 'dart:math';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/flashcard_data.dart';
import '../models/models.dart';
import '../services/drill_store.dart';
import '../services/study_store.dart';
import 'quiz_session_screen.dart';

/// GK Flash Quiz: Flashcards ke sawal-jawab se 4-option ka quiz banta hai.
/// Category chuno (ya "All") aur 10 sawal khelo. Galat sawal Smart Revision me
/// chale jaate hain. Sab kuch phone me - Firestore ko 0 reads / 0 writes.
class GkFlashQuizScreen extends StatefulWidget {
  const GkFlashQuizScreen({super.key});

  @override
  State<GkFlashQuizScreen> createState() => _GkFlashQuizScreenState();
}

class _GkFlashQuizScreenState extends State<GkFlashQuizScreen> {
  static const int _count = 10;
  String _cat = 'all';
  DrillBest? _best;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    try {
      final all = await DrillStore.allBest();
      if (!mounted) return;
      setState(() => _best = all['gk']);
    } catch (_) {
      // best nahi dikhega, baaki sab chalega
    }
  }

  int _cardsIn(String cat) => cat == 'all' ? kFlashcards.length : kFlashcards.where((c) => c.cat == cat).length;

  String _catTitle(String cat) {
    if (cat == 'all') return 'All Topics / सभी विषय';
    final v = kFlashCats[cat];
    return v == null ? cat : '${v[0]} / ${v[1]}';
  }

  List<MockQuestion> _build(String cat, int count) {
    final r = Random();
    final pool = kFlashcards.where((c) => cat == 'all' || c.cat == cat).toList()..shuffle(r);
    final out = <MockQuestion>[];
    for (final c in pool.take(count)) {
      // Galat options: pehle usi category ke doosre cards, phir baaki.
      final same = kFlashcards.where((x) => x.cat == c.cat && x.id != c.id && x.a != c.a).toList()..shuffle(r);
      final other = kFlashcards.where((x) => x.cat != c.cat && x.a != c.a).toList()..shuffle(r);
      final wrong = <Flashcard>[];
      for (final x in [...same, ...other]) {
        if (wrong.length == 3) break;
        if (wrong.any((w) => w.a == x.a)) continue;
        wrong.add(x);
      }
      if (wrong.length < 3) continue;
      final all = <Flashcard>[c, ...wrong];
      final order = <int>[0, 1, 2, 3]..shuffle(r);
      final label = kFlashCats[c.cat];
      out.add(MockQuestion(
        text: c.q,
        options: <String>[for (final i in order) all[i].a],
        correctIndex: order.indexOf(0),
        textHi: c.qh,
        optionsHi: <String>[for (final i in order) all[i].ah],
        explanation: label == null ? '' : 'Topic: ${label[0]}',
        explanationHi: label == null ? '' : 'विषय: ${label[1]}',
      ));
    }
    return out;
  }

  Future<void> _start() async {
    final qs = _build(_cat, _count);
    if (qs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not make a quiz. / क्विज़ नहीं बन सका।')),
      );
      return;
    }
    final title = 'GK Flash Quiz • ${_catTitle(_cat)}';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: title,
        questions: qs,
        onFinished: (answers) => _finish(title, qs, answers),
      ),
    ));
    if (mounted) _loadBest();
  }

  Future<void> _finish(String title, List<MockQuestion> qs, List<int?> answers) async {
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
      await StudyStore.addMistakes(wrong, subject: 'GK', source: 'GK Flash Quiz');
      await StudyStore.addGoalProgress(answered ~/ 2);
      await DrillStore.record(type: 'gk', correct: correct, answered: answered, total: qs.length);
    } catch (_) {
      // natija save na ho to bhi quiz ka result dikhta rahega
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = <String>['all', ...kFlashCats.keys];
    final n = _cardsIn(_cat);
    final shown = n < _count ? n : _count;
    final b = _best;
    return Scaffold(
      appBar: AppBar(title: const Text('GK Flash Quiz / जीके फ्लैश क्विज़')),
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
                  'Turn your flashcards into a quick MCQ quiz.\nफ्लैशकार्ड से झटपट MCQ क्विज़।',
                  style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  b == null
                      ? '${kFlashcards.length} cards ready • new mix every time\n${kFlashcards.length} कार्ड तैयार • हर बार नया मिक्स'
                      : 'Best: ${b.correct}/${b.total} (${b.percent}%)\nबेस्ट: ${b.correct}/${b.total} (${b.percent}%)',
                  style: TextStyle(color: AppC.text54, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Pick a topic / विषय चुनें', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in cats) _chip(c)],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: n < 4 ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text('Start $shown questions / शुरू करें'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String cat) {
    final active = cat == _cat;
    final v = kFlashCats[cat];
    final emoji = v == null ? '🎯' : v[2];
    final name = cat == 'all' ? 'All / सभी' : '${v == null ? cat : v[0]} / ${v == null ? '' : v[1]}';
    return GestureDetector(
      onTap: () => setState(() => _cat = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppC.gold : AppC.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? AppC.gold : AppC.line),
        ),
        child: Text(
          '$emoji $name (${_cardsIn(cat)})',
          style: TextStyle(color: active ? AppC.onGold : AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ),
    );
  }
}
