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
/// - [subject] == null  -> subject folders (if any test has a subject) and the
///   tests that have no subject. If NO test has a subject, just the tests
///   (exactly like before).
/// - [subject] != null  -> only the tests of that subject folder.
class MockTestListScreen extends StatefulWidget {
  final MockTestFolderModel folder;
  final String? subject;
  const MockTestListScreen({super.key, required this.folder, this.subject});

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

  Widget _subjectCard(MockSubjectGroup g) {
    return DepthCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestListScreen(folder: widget.folder, subject: g.name))),
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
    return Scaffold(
      appBar: AppBar(title: Text(subject ?? widget.folder.examName)),
      body: StreamBuilder<List<MockTestModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final all = snap.data!;

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
          final split = groupMockTestsBySubject(all);
          final items = <Widget>[
            ...split.groups.map(_subjectCard),
            if (split.groups.isNotEmpty && split.ungrouped.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 6, bottom: 8, left: 4),
                child: Text('Other tests', style: TextStyle(color: AppC.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ...split.ungrouped.map(_testCard),
          ];
          return ListView(padding: const EdgeInsets.all(14), children: items);
        },
      ),
    );
  }
}
