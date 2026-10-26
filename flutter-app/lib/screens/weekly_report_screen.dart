import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/share_service.dart';
import '../services/study_time_store.dart';
import '../services/weekly_report_service.dart';
import '../widgets/state_views.dart';

/// Weekly Report Card: pichhle 7 din ki padhai ka hisaab - score, active din,
/// sawal, study time, tests, syllabus aur speed maths. WhatsApp par share bhi
/// kar sakte hain. Data sirf phone me hai - Firestore ko 0 reads / 0 writes.
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  WeeklyReport? _r;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await WeeklyReportService.build();
      if (!mounted) return;
      setState(() {
        _r = r;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _share(WeeklyReport r) {
    ShareService.custom(
      context,
      '📈 My weekly report on Yash Study Hub / मेरी साप्ताहिक रिपोर्ट',
      r.shareText(StudyTimeStore.fmt(r.focusSec)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Report'),
        actions: [
          if (r != null)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _share(r),
            ),
        ],
      ),
      body: r == null
          ? (_failed ? const EmptyView('Could not build the report.\nरिपोर्ट नहीं बन सकी।') : const LoadingView())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _scoreCard(r),
                  const SizedBox(height: 12),
                  _activeStrip(r),
                  const SizedBox(height: 12),
                  _questionBars(r),
                  const SizedBox(height: 12),
                  _statsGrid(r),
                  if (r.strongSubject != null && r.weakSubject != null) ...[
                    const SizedBox(height: 12),
                    _subjectCard(r),
                  ],
                  const SizedBox(height: 12),
                  _tipsCard(r),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _share(r),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share report / रिपोर्ट शेयर करें', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Report covers the last 7 days and is made on your phone.\nरिपोर्ट पिछले 7 दिनों की है और आपके फ़ोन पर ही बनती है।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
    );
  }

  // --------------------------------------------------------------- cards

  Widget _scoreCard(WeeklyReport r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(r.rangeLabel, style: TextStyle(color: AppC.text54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(r.emoji, style: const TextStyle(fontSize: 44)),
          Text('${r.score}/100', style: TextStyle(color: AppC.text, fontSize: 38, fontWeight: FontWeight.w800)),
          Text('${r.title} / ${r.titleHi}', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (r.score / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 9,
              backgroundColor: AppC.line,
              color: AppC.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Weekly score = active days + study time + questions + tests\nसाप्ताहिक स्कोर = सक्रिय दिन + पढ़ाई का समय + सवाल + टेस्ट',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 10.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _activeStrip(WeeklyReport r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅ Active days: ${r.activeDays}/7 / सक्रिय दिन', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: r.active[i] ? AppC.gold : AppC.panel,
                          border: Border.all(color: r.active[i] ? AppC.gold : AppC.line),
                        ),
                        child: Text(
                          r.active[i] ? '✓' : '',
                          style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(WeeklyReport.dayNames[r.dates[i].weekday - 1], style: TextStyle(color: AppC.text54, fontSize: 10.5)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionBars(WeeklyReport r) {
    var maxQ = 20;
    for (final q in r.questionsPerDay) {
      if (q > maxQ) maxQ = q;
    }
    const maxBar = 70.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯 Questions per day / रोज़ के सवाल', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: maxBar + 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(r.questionsPerDay[i] == 0 ? '' : '${r.questionsPerDay[i]}', style: TextStyle(color: AppC.text70, fontSize: 10.5)),
                        const SizedBox(height: 3),
                        Container(
                          width: 18,
                          height: r.questionsPerDay[i] == 0 ? 3 : (r.questionsPerDay[i] / maxQ * maxBar).clamp(4.0, maxBar).toDouble(),
                          decoration: BoxDecoration(
                            color: r.questionsPerDay[i] == 0 ? AppC.line : AppC.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(WeeklyReport.dayNames[r.dates[i].weekday - 1], style: TextStyle(color: AppC.text54, fontSize: 10.5)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Pichhle hafte se kitna zyada / kam" - ek chhoti line aur uska rang.
  Widget _delta(int cur, int prev) {
    String text;
    Color color;
    if (prev == 0) {
      text = cur > 0 ? 'New this week 🎉 / इस हफ़्ते नया' : '—';
      color = cur > 0 ? AppC.green : AppC.text38;
    } else {
      final pct = ((cur - prev) / prev * 100).round();
      if (pct >= 0) {
        text = '▲ $pct% vs last week / पिछले हफ़्ते से';
        color = AppC.green;
      } else {
        text = '▼ ${pct.abs()}% vs last week / पिछले हफ़्ते से';
        color = AppC.orange;
      }
    }
    return Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600));
  }

  Widget _statTile(String emoji, String label, String value, Widget foot) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $label', style: TextStyle(color: AppC.text70, fontSize: 11.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w800, fontSize: 21)),
          const SizedBox(height: 3),
          foot,
        ],
      ),
    );
  }

  Widget _plainFoot(String text) => Text(text, style: TextStyle(color: AppC.text54, fontSize: 10.5));

  Widget _statsGrid(WeeklyReport r) {
    final tiles = <Widget>[
      _statTile('⏱️', 'Study time / पढ़ाई', StudyTimeStore.fmt(r.focusSec), _delta(r.focusSec, r.prevFocusSec)),
      _statTile('🎯', 'Questions / सवाल', '${r.questions}', _delta(r.questions, r.prevQuestions)),
      _statTile(
        '📝',
        'Tests & quizzes / टेस्ट',
        '${r.tests}',
        _plainFoot(r.tests == 0 ? 'No test yet / अभी कोई टेस्ट नहीं' : 'Avg score ${r.avgScore.round()}% · Accuracy ${r.accuracy.round()}%'),
      ),
      _statTile('📚', 'Syllabus topics / टॉपिक', '${r.topics}', _plainFoot('Done this week / इस हफ़्ते पूरे')),
      _statTile(
        '⚡',
        'Speed Maths / स्पीड मैथ्स',
        '${r.speedRounds}',
        _plainFoot(r.speedRounds == 0 ? 'rounds / राउंड' : 'rounds · ${r.speedCorrect} correct / सही'),
      ),
      _statTile('🔥', 'Streak / स्ट्रीक', '${r.streak}', _plainFoot('days in a row / लगातार दिन')),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _subjectCard(WeeklyReport r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📊 Subjects this week / इस हफ़्ते के विषय', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          Text('💪 Strongest / सबसे मज़बूत: ${r.strongSubject}', style: TextStyle(color: AppC.green, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('🎯 Needs work / सुधार चाहिए: ${r.weakSubject}', style: TextStyle(color: AppC.orange, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tipsCard(WeeklyReport r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.panel, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡 Next week tips / अगले हफ़्ते के सुझाव', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          for (final t in r.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${t.en}', style: TextStyle(color: AppC.textSoft, fontSize: 12.5, height: 1.3)),
                  Text('  ${t.hi}', style: TextStyle(color: AppC.text54, fontSize: 11.5, height: 1.3)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
