import 'package:flutter/material.dart';
import '../services/free_mcq_service.dart';
import '../services/mock_rank_service.dart' show fmtMarks;
import '../utils/open_link.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import 'mock_leaderboard_screen.dart';
import 'mock_test_attempt_screen.dart';
import '../app_colors.dart';

String _tests(int n) => '$n ${n == 1 ? 'test' : 'tests'}';

/// Free MCQs (home grid): exam folders -> subject folders -> one test per week.
/// Same format as Mock Tests: every weekly set is a test with a timer, marks,
/// negative marking, scorecard and leaderboard (it opens in the Mock Test exam
/// screen). Every set has 25 MCQs (Hindi + English). Wrong answers go to the
/// Mistake Notebook and the answered count to today's goal, via the scorecard.
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
                    'A new test of 25 MCQs every week (Monday): Static GK, General Science and General Studies (syllabus-based, Hindi + English), plus the English folder (Banking PO / Clerk pattern, easy to hard). Every test is timed and marked like a Mock Test, with a scorecard and a leaderboard. Tests older than 2 months are removed automatically. Tap ⓘ on a test to see how it was made.',
                    style: TextStyle(color: AppC.muted, fontSize: 12.5),
                  ),
                ),
                for (final e in index.exams)
                  DepthCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        // The English folder has a single subject, so it opens straight on its week list.
                        builder: (_) => e.id == kEnglishFolderId
                            ? _FreeMcqSubjectScreen(index: index, exam: e, subject: kEnglishFolder)
                            : _FreeMcqExamScreen(index: index, exam: e),
                      ),
                    ),
                    child: ListTile(
                      leading: Text(e.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(e.name, style: TextStyle(color: AppC.text)),
                      subtitle: Text(
                        e.id == kEnglishFolderId
                            ? 'Banking PO / Clerk pattern · ${_tests(index.setsForExam(e.id).length)}'
                            : _tests(index.setsForExam(e.id).length),
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
          for (final s in index.subjectsForExam(exam.id))
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
                  _tests(index.setsFor(exam.id, s.id).length),
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

/// Weekly sets for one exam + subject. Tapping one opens the 25-question quiz.
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
  String? _openingId; // the set being downloaded right now (spinner on its tile)

  /// Opens the set in the Mock Test exam screen (timer, marks, scorecard, leaderboard).
  Future<void> _open(FreeMcqSetMeta meta) async {
    if (_openingId != null) return;
    setState(() => _openingId = meta.id);

    final FreeMcqSet set;
    try {
      set = await _svc.loadSet(meta);
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This test could not be opened. Check your internet and try again.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _openingId = null);

    final test = FreeMcqService.toMockTest(
      meta: meta,
      subjectName: widget.subject.name,
      subject: widget.subject.name,
      set: set,
      settings: widget.index.settings,
    );
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestAttemptScreen(test: test)));
  }

  /// "About this set" (how it was made). Uses the same single read the quiz needs (then cached).
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
              Text('About this test', style: TextStyle(color: AppC.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                set.sources.isNotEmpty
                    ? 'These questions are written from official PIB (Government of India) press releases. The source is credited in each explanation. '
                        'Questions can contain mistakes, so please check important facts in your textbook.'
                    : widget.subject.id == kEnglishFolderId
                        ? 'These English questions follow the Banking PO / Clerk pattern (reading comprehension, cloze test, error spotting, fill in the blanks, para jumbles, sentence improvement) at easy, moderate and hard level (a new set every week). '
                            'They are written by AI and checked twice for accuracy (grammar check and an independent re-solve). No book or website text is copied. Questions can still contain mistakes, so please confirm doubtful points in a grammar book.'
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

  /// Same line as a Mock Test tile: questions, time, marks, negative marking.
  String _subtitle(FreeMcqSetMeta m) {
    final st = widget.index.settings;
    return '${m.count} questions \u2022 ${st.durationMinutes > 0 ? '${st.durationMinutes} min' : 'No timer'} \u2022 ${fmtMarks(m.count * st.marksPerQuestion)} marks'
        '${st.negativeMarks > 0 ? ' \u2022 \u2212${fmtMarks(st.negativeMarks)} negative' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.index.setsFor(widget.exam.id, widget.subject.id);
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject.name)),
      body: sets.isEmpty
          ? EmptyView(widget.subject.id == kEnglishFolderId
              ? 'The English test for this week is not ready yet. A new test of 25 English MCQs arrives automatically every Monday.'
              : 'No test for this subject yet. A new test of 25 MCQs arrives automatically every Monday.')
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final m in sets)
                  DepthCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: _openingId == null ? () => _open(m) : null,
                    child: ListTile(
                      leading: const Text('📝', style: TextStyle(fontSize: 22)),
                      title: Text(FreeMcqService.setLabel(m), style: TextStyle(color: AppC.text)),
                      subtitle: Text(_subtitle(m), style: TextStyle(color: AppC.muted, fontSize: 11)),
                      trailing: _openingId == m.id
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Leaderboard: rank list by marks only (no names), same as Mock Tests.
                                IconButton(
                                  tooltip: 'Leaderboard',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Text('\u{1F3C6}', style: TextStyle(fontSize: 20)),
                                  onPressed: _openingId == null
                                      ? () => Navigator.of(context).push(MaterialPageRoute(
                                            builder: (_) => MockLeaderboardScreen(
                                              testId: m.id,
                                              testTitle: '${widget.subject.name} \u00b7 ${FreeMcqService.setLabel(m)}',
                                            ),
                                          ))
                                      : null,
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'About this test',
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
