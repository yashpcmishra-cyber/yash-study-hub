import 'package:flutter/material.dart';
import '../services/share_service.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import '../services/mock_rank_service.dart';
import 'mock_test_attempt_screen.dart';
import 'mock_leaderboard_screen.dart';
import '../app_colors.dart';

/// Inside an exam folder:
/// - If some tests are marked Prelims / Mains, the first level shows a
///   "Prelims" and a "Mains" folder (plus the tests that have no category).
/// - [stage] == null -> not inside a category (the exam folder's first level).
///   [stage] == '' -> only tests WITHOUT a category (shown under "Other tests").
///   [stage] == 'prelims' / 'mains' -> only that category's tests.
/// - [subject] == null  -> subject folders (if any test has a subject) and the
///   tests that have no subject. If NO test has a subject, just the tests
///   (exactly like before).
/// - [subject] != null  -> only the tests of that subject folder.
class MockTestListScreen extends StatefulWidget {
  final MockTestFolderModel folder;
  final String? subject;
  final String? stage;
  const MockTestListScreen({super.key, required this.folder, this.subject, this.stage});

  @override
  State<MockTestListScreen> createState() => _MockTestListScreenState();
}

class _MockTestListScreenState extends State<MockTestListScreen> {
  final _fs = FirestoreService();
  late final Stream<List<MockTestModel>> _stream = _fs.streamMockTests(widget.folder.id);

  Widget _testCard(MockTestModel t) {
    return DepthCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestAttemptScreen(test: t))),
      child: ListTile(
        leading: const Text('📝', style: TextStyle(fontSize: 22)),
        title: Text(t.title, style: TextStyle(color: AppC.text)),
        subtitle: Text(
          '${t.questions.length} questions \u2022 ${t.durationMinutes > 0 ? '${t.durationMinutes} min' : 'No timer'} \u2022 ${fmtMarks(t.questions.length * t.marksPerQuestion)} marks'
          '${t.negativeMarks > 0 ? ' \u2022 \u2212${fmtMarks(t.negativeMarks)} negative' : ''}',
          style: TextStyle(color: AppC.muted, fontSize: 11),
        ),
        // Share button only when this folder is FREE (paid-batch tests are never shareable).
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Leaderboard: sirf marks ke hisaab se rank list (naam nahi dikhte).
            IconButton(
              tooltip: 'Leaderboard',
              visualDensity: VisualDensity.compact,
              icon: const Text('\u{1F3C6}', style: TextStyle(fontSize: 20)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MockLeaderboardScreen(testId: t.id, testTitle: t.title),
              )),
            ),
            if (widget.folder.isFree) ShareButton(onPressed: () => ShareService.freeMock(context, t.title)),
            Icon(Icons.chevron_right, color: AppC.muted),
          ],
        ),
      ),
    );
  }

  Widget _stageCard(String stage, List<MockTestModel> tests) {
    return DepthCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestListScreen(folder: widget.folder, stage: stage))),
      child: ListTile(
        leading: Text(mockStageEmoji(stage), style: const TextStyle(fontSize: 22)),
        title: Text(mockStageLabel(stage), style: TextStyle(color: AppC.text)),
        subtitle: Text('${tests.length} ${tests.length == 1 ? 'test' : 'tests'}', style: TextStyle(color: AppC.muted, fontSize: 11)),
        trailing: Icon(Icons.chevron_right, color: AppC.muted),
      ),
    );
  }

  Widget _subjectCard(MockSubjectGroup g, String? stage) {
    return DepthCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestListScreen(folder: widget.folder, subject: g.name, stage: stage))),
      child: ListTile(
        leading: const Text('📚', style: TextStyle(fontSize: 22)),
        title: Text(g.name, style: TextStyle(color: AppC.text)),
        subtitle: Text('${g.tests.length} ${g.tests.length == 1 ? 'test' : 'tests'}', style: TextStyle(color: AppC.muted, fontSize: 11)),
        trailing: Icon(Icons.chevron_right, color: AppC.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final stageArg = widget.stage;
    final stageTitle = (stageArg != null && stageArg.isNotEmpty) ? mockStageLabel(stageArg) : (stageArg == '' ? 'Other tests' : null);
    return Scaffold(
      appBar: AppBar(
        title: Text(subject != null
            ? (stageTitle != null && stageArg!.isNotEmpty ? '$stageTitle \u2022 $subject' : subject)
            : (stageTitle ?? widget.folder.examName)),
      ),
      body: StreamBuilder<List<MockTestModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final everything = snap.data!;
          final byStage = splitMockTestsByStage(everything);

          // First level of an exam folder that has Prelims / Mains tests.
          if (stageArg == null && subject == null && byStage.hasStages) {
            return ListView(padding: const EdgeInsets.all(14), children: [
              if (byStage.prelims.isNotEmpty) _stageCard(kStagePrelims, byStage.prelims),
              if (byStage.mains.isNotEmpty) _stageCard(kStageMains, byStage.mains),
              if (byStage.none.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8, left: 4),
                  child: Text('Other tests', style: TextStyle(color: AppC.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ..._subjectSplitItems(byStage.none, ''),
              ],
            ]);
          }

          // The tests this screen is about: the whole folder, or one category of it.
          // (When the folder has categories, a subject opened from the first level
          // belongs to the untagged tests: stage ''.)
          final List<MockTestModel> all;
          if (stageArg == null) {
            all = byStage.hasStages ? byStage.none : everything;
          } else if (stageArg == kStagePrelims) {
            all = byStage.prelims;
          } else if (stageArg == kStageMains) {
            all = byStage.mains;
          } else {
            all = byStage.none;
          }

          // Inside one subject folder: only that subject's tests.
          if (subject != null) {
            final key = mockSubjectKey(subject);
            final tests = all.where((t) => mockSubjectKey(t.subject) == key).toList();
            if (tests.isEmpty) return const EmptyView('No mock test in this subject yet');
            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: tests.length,
              itemBuilder: (context, i) => _testCard(tests[i]),
            );
          }

          if (all.isEmpty) return const EmptyView('No mock test in this folder yet');
          return ListView(padding: const EdgeInsets.all(14), children: _subjectSplitItems(all, stageArg));
        },
      ),
    );
  }

  /// Subject folders first, then the tests that have no subject.
  List<Widget> _subjectSplitItems(List<MockTestModel> tests, String? stageForSubjects) {
    final split = groupMockTestsBySubject(tests);
    return <Widget>[
      ...split.groups.map((g) => _subjectCard(g, stageForSubjects)),
      if (split.groups.isNotEmpty && split.ungrouped.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8, left: 4),
          child: Text('Other tests', style: TextStyle(color: AppC.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ...split.ungrouped.map(_testCard),
    ];
  }
}
