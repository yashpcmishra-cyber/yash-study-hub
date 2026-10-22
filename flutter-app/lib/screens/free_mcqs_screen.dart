import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/free_mcq_service.dart';
import '../services/study_store.dart';
import '../utils/open_link.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import 'quiz_session_screen.dart';
import '../app_colors.dart';

/// Free MCQs (home grid): exam folders -> subject folders -> one folder per month.
/// Every set has 25 MCQs (Hindi + English). Wrong answers go to the Mistake
/// Notebook and the answered count goes to today's goal, same as the other quizzes.
class FreeMcqsScreen extends StatefulWidget {
  const FreeMcqsScreen({super.key});

  @override
  State<FreeMcqsScreen> createState() => _FreeMcqsScreenState();
}

class _FreeMcqsScreenState extends State<FreeMcqsScreen> {
  final _svc = FreeMcqService();
  late Future<FreeMcqIndex?> _index;

  @override
  void initState() {
    super.initState();
    _index = _svc.loadIndex();
  }

  Future<void> _refresh() async {
    setState(() => _index = _svc.loadIndex(force: true));
    await _index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Free MCQs')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<FreeMcqIndex?>(
          future: _index,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const PullableMessage(child: LoadingView());
            }
            if (snap.hasError) {
              return PullableMessage(child: ErrorView(error: snap.error));
            }
            final index = snap.data;
            if (index == null || index.exams.isEmpty || index.sets.isEmpty) {
              return const PullableMessage(child: EmptyView('Free MCQs are not ready yet. Please check again later.'));
            }
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                  child: Text(
                    'A new set of 25 MCQs every month: Current Affairs (from PIB), Static GK, General Science and General Studies (syllabus-based). Tap ⓘ on a month to see how it was made.',
                    style: TextStyle(color: AppC.muted, fontSize: 12.5),
                  ),
                ),
                for (final e in index.exams)
                  DepthCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => _FreeMcqExamScreen(index: index, exam: e)),
                    ),
                    child: ListTile(
                      leading: Text(e.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(e.name, style: TextStyle(color: AppC.text)),
                      subtitle: Text(
                        '${index.setsForExam(e.id).length} sets',
                        style: TextStyle(color: AppC.muted, fontSize: 11),
                      ),
                      trailing: Icon(Icons.chevron_right, color: AppC.muted),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Subject folders inside one exam.
class _FreeMcqExamScreen extends StatelessWidget {
  final FreeMcqIndex index;
  final FreeMcqChoice exam;
  const _FreeMcqExamScreen({required this.index, required this.exam});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exam.name)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (final s in index.subjects)
            DepthCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _FreeMcqSubjectScreen(index: index, exam: exam, subject: s),
                ),
              ),
              child: ListTile(
                leading: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(s.name, style: TextStyle(color: AppC.text)),
                subtitle: Text(
                  '${index.setsFor(exam.id, s.id).length} months',
                  style: TextStyle(color: AppC.muted, fontSize: 11),
                ),
                trailing: Icon(Icons.chevron_right, color: AppC.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Month folders for one exam + subject. Tapping one opens the 25-question quiz.
class _FreeMcqSubjectScreen extends StatefulWidget {
  final FreeMcqIndex index;
  final FreeMcqChoice exam;
  final FreeMcqChoice subject;
  const _FreeMcqSubjectScreen({required this.index, required this.exam, required this.subject});

  @override
  State<_FreeMcqSubjectScreen> createState() => _FreeMcqSubjectScreenState();
}

class _FreeMcqSubjectScreenState extends State<_FreeMcqSubjectScreen> {
  final _svc = FreeMcqService();
  Map<String, String> _done = <String, String>{};
  String? _openingId; // the set being downloaded right now (spinner on its tile)

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  Future<void> _loadDone() async {
    final d = await _svc.doneScores();
    if (mounted) setState(() => _done = d);
  }

  Future<void> _open(FreeMcqSetMeta meta) async {
    if (_openingId != null) return;
    setState(() => _openingId = meta.id);

    final List<MockQuestion> qs;
    try {
      qs = (await _svc.loadSet(meta)).questions;
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This set could not be opened. Check your internet and try again.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _openingId = null);

    final month = FreeMcqService.monthLabel(meta.monthKey);
    final title = '${widget.subject.name} · $month';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizSessionScreen(
          title: title,
          questions: qs,
          bookmarkSource: '${widget.exam.name} · $title',
          onFinished: (answers) => _finish(meta, qs, answers),
        ),
      ),
    );
    _loadDone(); // show the new score on the tile
  }

  /// Saves the score on this phone, wrong answers to the Mistake Notebook, and the goal count.
  Future<void> _finish(FreeMcqSetMeta meta, List<MockQuestion> qs, List<int?> answers) async {
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
    await _svc.markDone(meta.id, correct, qs.length);
    await StudyStore.addMistakes(
      wrong,
      subject: widget.subject.name,
      source: '${widget.exam.name} · ${FreeMcqService.monthLabel(meta.monthKey)}',
    );
    await StudyStore.addGoalProgress(answered);
  }

  /// "About this set" (how it was made, and the PIB link for Current Affairs). Uses the same single read the quiz needs (then cached).
  Future<void> _showSources(FreeMcqSetMeta meta) async {
    final FreeMcqSet set;
    try {
      set = await _svc.loadSet(meta);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details could not be loaded. Check your internet and try again.')),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            children: [
              Text('About this set', style: TextStyle(color: AppC.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                set.sources.isNotEmpty
                    ? 'These questions are written from official PIB (Government of India) press releases. The source is credited in each explanation. '
                        'Questions can contain mistakes, so please check important facts in your textbook.'
                    : 'These questions are written by AI from the syllabus topics of this exam and checked three times for accuracy (fact-check, independent re-solve, Hindi-English match). '
                        'No book or website text is copied. Questions can still contain mistakes, so please check important facts in your textbook.',
                style: TextStyle(color: AppC.muted, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 6),
              for (final src in set.sources)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link, size: 18, color: AppC.muted),
                  title: Text(src.title, style: TextStyle(color: AppC.text, fontSize: 13)),
                  onTap: src.url.isEmpty ? null : () => openExternalLink(sheetContext, src.url),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(FreeMcqSetMeta m) {
    final parts = <String>['${m.count} MCQs'];
    if (m.source.isNotEmpty) parts.add(m.source);
    final score = _done[m.id];
    if (score != null) parts.add('Score $score');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.index.setsFor(widget.exam.id, widget.subject.id);
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject.name)),
      body: sets.isEmpty
          ? const EmptyView('No set for this subject yet.')
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final m in sets)
                  DepthCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: _openingId == null ? () => _open(m) : null,
                    child: ListTile(
                      leading: Icon(
                        _done.containsKey(m.id) ? Icons.check_circle : Icons.quiz_outlined,
                        color: _done.containsKey(m.id) ? Colors.green : AppC.muted,
                      ),
                      title: Text(FreeMcqService.monthLabel(m.monthKey), style: TextStyle(color: AppC.text)),
                      subtitle: Text(_subtitle(m), style: TextStyle(color: AppC.muted, fontSize: 11)),
                      trailing: _openingId == m.id
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'About this set',
                                  icon: Icon(Icons.info_outline, size: 20, color: AppC.muted),
                                  onPressed: _openingId == null ? () => _showSources(m) : null,
                                ),
                                Icon(Icons.chevron_right, color: AppC.muted),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
    );
  }
}
