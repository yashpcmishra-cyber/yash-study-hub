import 'dart:math';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/syllabus_data.dart';
import '../services/study_store.dart';
import '../services/syllabus_store.dart';
import '../widgets/state_views.dart';

/// Syllabus Tracker: exam chuno, har topic poora hone par tick karo.
/// Exam countdown ke saath "har hafte kitne topics" ka hisaab bhi dikhta hai.
/// Data sirf phone me hai - Firestore ko 0 reads / 0 writes.
class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  bool _loading = true;
  String _examId = '';
  Map<String, String> _done = <String, String>{};
  ExamTarget _target = const ExamTarget('', null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await SyllabusStore.selectedExamId();
      final done = await SyllabusStore.doneMap();
      final target = await StudyStore.readExam();
      if (!mounted) return;
      setState(() {
        _examId = id;
        _done = done;
        _target = target;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  SylExam? get _exam => sylExamById(_examId);

  Future<void> _chooseExam(String id) async {
    setState(() => _examId = id);
    await SyllabusStore.setExam(id);
  }

  Future<void> _toggle(SylExam exam, SylSubject subject, SylTopic t, bool value) async {
    setState(() {
      if (value) {
        _done[t.id] = StudyStore.today();
      } else {
        _done.remove(t.id);
      }
    });
    await SyllabusStore.setDone(t.id, value);
    if (!mounted || !value) return;
    final all = SyllabusStore.doneCount(exam, _done) >= exam.totalTopics;
    final subjectDone = subject.topics.every((x) => _done.containsKey(x.id));
    if (all) {
      _snack('🏆 Full syllabus complete! Now revise & take mocks.\nपूरा सिलेबस हो गया! अब रिवीज़न और मॉक टेस्ट।');
    } else if (subjectDone) {
      _snack('🎉 ${subject.en} complete! / ${subject.hi} पूरा!');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate(SylExam exam) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = (_target.date != null && !_target.date!.isBefore(today)) ? _target.date! : today.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 3, today.month, today.day),
      helpText: 'Exam date / परीक्षा की तारीख',
    );
    if (picked == null) return;
    final name = _target.name.isNotEmpty ? _target.name : (exam.en.length > 30 ? exam.en.substring(0, 30) : exam.en);
    await StudyStore.saveExam(name, picked);
    await _load();
  }

  Future<void> _confirmReset(SylExam exam) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card2,
        title: Text('Reset progress? / प्रोग्रेस रीसेट करें?', style: TextStyle(color: AppC.text, fontSize: 16)),
        content: Text(
          'All ticks of ${exam.en} will be cleared.\n${exam.hi} के सभी टिक हट जाएँगे।',
          style: TextStyle(color: AppC.text70, fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel / रद्द', style: TextStyle(color: AppC.text70))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Reset / रीसेट', style: TextStyle(color: AppC.red))),
        ],
      ),
    );
    if (ok != true) return;
    await SyllabusStore.resetExam(exam);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final exam = _exam;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus Tracker'),
        actions: [
          if (exam != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reset') _confirmReset(exam);
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(value: 'reset', child: Text('Reset this exam / इस परीक्षा को रीसेट करें')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : exam == null
              ? _examPicker()
              : _tracker(exam),
    );
  }

  // -------------------------------------------------------------- picker

  Widget _examPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Choose your exam / अपनी परीक्षा चुनें', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          'Tick every topic you finish and watch your syllabus fill up.\nजो टॉपिक पूरा करें उस पर टिक करें।',
          style: TextStyle(color: AppC.text60, fontSize: 12.5, height: 1.35),
        ),
        const SizedBox(height: 14),
        for (final e in kSylExams)
          GestureDetector(
            onTap: () => _chooseExam(e.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppC.line)),
              child: Row(
                children: [
                  Text(e.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.en, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14.5)),
                        Text(e.hi, style: TextStyle(color: AppC.text70, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text('${e.subjects.length} subjects · ${e.totalTopics} topics', style: TextStyle(color: AppC.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppC.text54),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- tracker

  Widget _tracker(SylExam exam) {
    final done = SyllabusStore.doneCount(exam, _done);
    final total = exam.totalTopics;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _examChips(exam),
          const SizedBox(height: 12),
          _progressCard(exam, done, total),
          const SizedBox(height: 12),
          for (var i = 0; i < exam.subjects.length; i++) _subjectTile(exam, exam.subjects[i], i == 0),
          const SizedBox(height: 6),
          Text(
            'Based on the common exam pattern. Always check the official notification for the latest syllabus.\n'
            'यह आम पैटर्न पर आधारित है। नए सिलेबस के लिए आधिकारिक अधिसूचना ज़रूर देखें।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _examChips(SylExam exam) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in kSylExams)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _chooseExam(e.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: e.id == exam.id ? AppC.goldWash2 : AppC.card2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: e.id == exam.id ? AppC.gold : AppC.line, width: e.id == exam.id ? 1.6 : 1),
                  ),
                  child: Text('${e.emoji} ${e.en}', style: TextStyle(color: AppC.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _progressCard(SylExam exam, int done, int total) {
    final ratio = total == 0 ? 0.0 : done / total;
    final pct = (ratio * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: ratio.clamp(0.0, 1.0).toDouble(),
                        strokeWidth: 8,
                        backgroundColor: AppC.line,
                        color: AppC.gold,
                      ),
                    ),
                    Text('$pct%', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$done / $total topics done', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('$done / $total टॉपिक पूरे', style: TextStyle(color: AppC.text70, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(exam.en, style: TextStyle(color: AppC.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _paceBlock(exam, done, total),
        ],
      ),
    );
  }

  Widget _paceBlock(SylExam exam, int done, int total) {
    final left = total - done;
    final target = _target;
    String line;
    if (!target.isSet) {
      line = 'Set your exam date to get a weekly plan.\nहफ़्ते की योजना पाने के लिए परीक्षा की तारीख डालें।';
    } else {
      final days = target.daysLeft();
      if (days < 0) {
        line = 'Your exam date has passed — set a new date.\nपरीक्षा की तारीख निकल गई — नई तारीख डालें।';
      } else if (left <= 0) {
        line = '✅ Whole syllabus done! Revise and attempt mock tests.\n✅ पूरा सिलेबस हो गया! रिवीज़न करें और मॉक टेस्ट दें।';
      } else if (days == 0) {
        line = 'Exam is today — all the best! / आज परीक्षा है — शुभकामनाएँ!';
      } else {
        final weeks = max(1.0, days / 7.0);
        final perWeek = (left / weeks).ceil();
        line = '📅 $days days to ${target.name.isEmpty ? 'exam' : target.name} · $left topics left\n'
            '👉 About $perWeek topics per week.\n'
            '👉 हर हफ़्ते लगभग $perWeek टॉपिक पूरे करें।';
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppC.panel, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line, style: TextStyle(color: AppC.textSoft, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickDate(exam),
            child: Text(
              target.isSet ? 'Change exam date / तारीख बदलें' : 'Set exam date / परीक्षा तिथि चुनें',
              style: TextStyle(color: AppC.accent, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectTile(SylExam exam, SylSubject s, bool first) {
    final d = s.topics.where((t) => _done.containsKey(t.id)).length;
    final total = s.topics.length;
    final ratio = total == 0 ? 0.0 : d / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('syl_${exam.id}_${s.id}'),
          initiallyExpanded: first,
          iconColor: AppC.accent,
          collapsedIconColor: AppC.text70,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text('${s.emoji} ${s.en}', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.hi} · $d/$total', style: TextStyle(color: AppC.text70, fontSize: 12)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0).toDouble(),
                    minHeight: 5,
                    backgroundColor: AppC.line,
                    color: ratio >= 1 ? AppC.green : AppC.gold,
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final t in s.topics)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppC.gold,
                checkColor: AppC.onGold,
                side: BorderSide(color: AppC.text54, width: 1.5),
                value: _done.containsKey(t.id),
                onChanged: (v) => _toggle(exam, s, t, v ?? false),
                title: Text(
                  t.en,
                  style: TextStyle(
                    color: _done.containsKey(t.id) ? AppC.text54 : AppC.text,
                    fontSize: 13.5,
                    decoration: _done.containsKey(t.id) ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                subtitle: Text(t.hi, style: TextStyle(color: AppC.text54, fontSize: 11.5)),
              ),
          ],
        ),
      ),
    );
  }
}
