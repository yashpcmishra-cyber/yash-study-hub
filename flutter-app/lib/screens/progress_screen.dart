import 'package:flutter/material.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';
import '../widgets/study_time_chart.dart';
import 'quiz_session_screen.dart';

import '../app_colors.dart';

class _SubjectStat {
  final String name;
  int correct = 0;
  int attempted = 0;
  int tests = 0;
  _SubjectStat(this.name);
  double get accuracy => attempted == 0 ? 0 : correct / attempted * 100;
}

/// My Progress: pichhle 30 din ke mock tests / quiz ka hisaab - score trend,
/// subject-wise accuracy aur kamzor subject. Data sirf phone se aata hai
/// (Firestore ki koi read nahi).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<TestRecord>? _records;
  StreakInfo _streak = const StreakInfo(0);
  List<SavedQuestion> _mistakes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await StudyStore.history();
    final s = await StudyStore.readStreak();
    final m = await StudyStore.mistakes();
    if (!mounted) return;
    setState(() {
      _records = r;
      _streak = s;
      _mistakes = m;
    });
  }

  /// Notebook ki galtiyon me se us subject ki galtiyan ("General" = jis test ka subject khali tha).
  List<SavedQuestion> _mistakesFor(String subject) {
    final key = subject.trim().toLowerCase();
    return _mistakes.where((e) {
      var s = e.subject.trim().toLowerCase();
      if (s.isEmpty) s = 'general';
      return s == key;
    }).toList();
  }

  /// "Meri kamzori sudharo": sabse kamzor subject ke (max 10) galat sawal ka quiz.
  /// Sahi kiye sawal notebook se hat jaate hain aur har sudhari galti par XP milta hai.
  Future<void> _fixWeakness(String subject) async {
    final items = _mistakesFor(subject).take(10).toList();
    if (items.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: 'Fix: $subject',
        questions: items.map((e) => e.question).toList(),
        bookmarkSource: 'Fix weakness',
        onFinished: (answers) => StudyStore.recordPractice(
          items: items,
          answers: answers,
          removeCorrectFromMistakes: true,
        ),
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: records == null
          ? const LoadingView()
          : records.isEmpty
              ? Column(
                  children: [
                    const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: StudyTimeChart()),
                    const Expanded(
                      child: EmptyView('No data yet.\nTake a Mock Test or Daily Quiz \u2014 your progress will show up here.\n\nअभी कोई डेटा नहीं है।\nकोई मॉक टेस्ट या डेली क्विज़ दीजिए, फिर प्रोग्रेस यहाँ दिखेगा।'),
                    ),
                  ],
                )
              : _content(records),
    );
  }

  Widget _content(List<TestRecord> records) {
    // ---- overall
    var correct = 0;
    var attempted = 0;
    var pctSum = 0.0;
    var best = 0.0;
    for (final r in records) {
      correct += r.correct;
      attempted += r.attempted;
      pctSum += r.scorePercent;
      if (r.scorePercent > best) best = r.scorePercent;
    }
    final avgAcc = attempted == 0 ? 0.0 : correct / attempted * 100;
    final avgScore = pctSum / records.length;

    // ---- last 10 tests, purane se naye (left -> right)
    final last10 = records.take(10).toList().reversed.toList();

    // ---- subject wise
    final bySubject = <String, _SubjectStat>{};
    for (final r in records) {
      if (r.attempted == 0) continue;
      final name = r.subject.trim().isEmpty ? 'General' : r.subject.trim();
      final key = name.toLowerCase();
      final s = bySubject.putIfAbsent(key, () => _SubjectStat(name));
      s.correct += r.correct;
      s.attempted += r.attempted;
      s.tests += 1;
    }
    final subjects = bySubject.values.toList()..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final weak = subjects.length >= 2 ? subjects.first : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            _tile('Tests', '${records.length}', AppC.text),
            const SizedBox(width: 8),
            _tile('Avg score', '${avgScore.toStringAsFixed(0)}%', AppC.accent),
            const SizedBox(width: 8),
            _tile('Accuracy', '${avgAcc.toStringAsFixed(0)}%', AppC.green),
            const SizedBox(width: 8),
            _tile('Best', '${best.toStringAsFixed(0)}%', AppC.text),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _streak.days == 0
                      ? 'Finish your daily goal to start your streak.\nस्ट्रीक शुरू करने के लिए रोज़ का लक्ष्य पूरा करें।'
                      : 'Streak: ${_streak.days} days / दिन  (${_streak.filled}/7)  •  ❄️ ${_streak.freezes}'
                          '${_streak.completedWeeks > 0 ? '  •  🏆 ${_streak.completedWeeks}x 7 days / 7 दिन पूरे' : ''}',
                  style: TextStyle(color: AppC.text, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          const StudyTimeChart(),
          const SizedBox(height: 18),
          Text('Recent tests score (%) / पिछले टेस्ट का स्कोर (%)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
            child: SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < last10.length; i++) _bar(last10[i], i + 1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Subject-wise accuracy', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (subjects.isEmpty)
            Text('No subject data yet. / अभी विषय का डेटा नहीं है।', style: TextStyle(color: AppC.muted, fontSize: 12))
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [for (final s in subjects) _subjectRow(s)]),
            ),
          if (weak != null) ...[
            const SizedBox(height: 12),
            _weakCard(weak),
          ],
          const SizedBox(height: 14),
          Text(
            'This data stays only on your phone and is removed after 30 days.\nयह डेटा केवल आपके फ़ोन में है और 30 दिन बाद अपने आप हट जाता है।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _weakCard(_SubjectStat weak) {
    final mine = _mistakesFor(weak.name);
    final n = mine.length > 10 ? 10 : mine.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Weakest: ${weak.name} (${weak.accuracy.toStringAsFixed(0)}%). Practice this more.\nसबसे कमज़ोर: ${weak.name}। इसमें ज़्यादा अभ्यास करें।',
            style: TextStyle(color: AppC.text, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          if (n > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _fixWeakness(weak.name),
                icon: const Icon(Icons.fitness_center, size: 18),
                label: Text('Fix my weakness: $n questions / मेरी कमज़ोरी सुधारो: $n सवाल'),
              ),
            )
          else
            Text(
              'No saved mistakes for this subject right now. Take another test in it, and the questions you get wrong will appear here to practice.\nइस विषय की कोई गलती अभी सेव नहीं है। इसका एक और टेस्ट दें, गलत सवाल यहाँ प्रैक्टिस के लिए आ जाएँगे।',
              style: TextStyle(color: AppC.text70, fontSize: 11.5, height: 1.35),
            ),
          if (n > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Correct answers are removed from your Mistake Notebook, and you earn +5 XP for each one you fix.\nसही किए सवाल Mistake Notebook से हट जाते हैं, हर सुधारी गलती पर +5 XP।',
              style: TextStyle(color: AppC.text70, fontSize: 11, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: AppC.muted, fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _bar(TestRecord r, int n) {
    final p = r.scorePercent;
    final h = 100.0 * p / 100.0;
    final Color c = p >= 70 ? AppC.green : (p >= 40 ? AppC.mid : AppC.red);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(p.toStringAsFixed(0), style: TextStyle(color: AppC.text70, fontSize: 10))),
            const SizedBox(height: 3),
            Container(height: h < 3 ? 3 : h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Text('$n', style: TextStyle(color: AppC.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _subjectRow(_SubjectStat s) {
    final acc = s.accuracy;
    final Color c = acc >= 70 ? AppC.green : (acc >= 40 ? AppC.mid : AppC.red);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontSize: 13))),
            Text('${acc.toStringAsFixed(0)}%  •  ${s.attempted} Qs / सवाल', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: acc / 100, minHeight: 7, backgroundColor: AppC.card, color: c),
          ),
        ],
      ),
    );
  }
}
