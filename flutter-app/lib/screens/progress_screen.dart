import 'package:flutter/material.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';

const _navy = Color(0xFF081136);
const _cardBg = Color(0xFF101D57);
const _gold = Color(0xFFFFFF29);

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await StudyStore.history();
    final s = await StudyStore.readStreak();
    if (!mounted) return;
    setState(() {
      _records = r;
      _streak = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: records == null
          ? const LoadingView()
          : records.isEmpty
              ? const EmptyView('No data yet.\nTake a Mock Test or Daily Quiz \u2014 your progress will show up here.\n\nअभी कोई डेटा नहीं है।\nकोई मॉक टेस्ट या डेली क्विज़ दीजिए, फिर प्रोग्रेस यहाँ दिखेगा।')
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
            _tile('Tests', '${records.length}', Colors.white),
            const SizedBox(width: 8),
            _tile('Avg score', '${avgScore.toStringAsFixed(0)}%', _gold),
            const SizedBox(width: 8),
            _tile('Accuracy', '${avgAcc.toStringAsFixed(0)}%', Colors.greenAccent),
            const SizedBox(width: 8),
            _tile('Best', '${best.toStringAsFixed(0)}%', Colors.white),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _streak.days == 0
                      ? 'Open the app every day to start your streak.\nस्ट्रीक शुरू करने के लिए रोज़ ऐप खोलें।'
                      : 'Streak: ${_streak.filled}/7 days / दिन'
                          '${_streak.completedWeeks > 0 ? '  •  🏆 ${_streak.completedWeeks}x 7 days / 7 दिन पूरे' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Recent tests score (%) / पिछले टेस्ट का स्कोर (%)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)),
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
          const Text('Subject-wise accuracy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (subjects.isEmpty)
            const Text('No subject data yet. / अभी विषय का डेटा नहीं है।', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [for (final s in subjects) _subjectRow(s)]),
            ),
          if (weak != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x22FFFF29), borderRadius: BorderRadius.circular(12)),
              child: Text(
                '💡 Weakest: ${weak.name} (${weak.accuracy.toStringAsFixed(0)}%). Practice this more.\nसबसे कमज़ोर: ${weak.name}। इसमें ज़्यादा अभ्यास करें।',
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'This data stays only on your phone and is removed after 30 days.\nयह डेटा केवल आपके फ़ोन में है और 30 दिन बाद अपने आप हट जाता है।',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _bar(TestRecord r, int n) {
    final p = r.scorePercent;
    final h = 100.0 * p / 100.0;
    final Color c = p >= 70 ? Colors.greenAccent : (p >= 40 ? _gold : Colors.redAccent);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(p.toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 10))),
            const SizedBox(height: 3),
            Container(height: h < 3 ? 3 : h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Text('$n', style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _subjectRow(_SubjectStat s) {
    final acc = s.accuracy;
    final Color c = acc >= 70 ? Colors.greenAccent : (acc >= 40 ? _gold : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13))),
            Text('${acc.toStringAsFixed(0)}%  •  ${s.attempted} Qs / सवाल', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: acc / 100, minHeight: 7, backgroundColor: _navy, color: c),
          ),
        ],
      ),
    );
  }
}
