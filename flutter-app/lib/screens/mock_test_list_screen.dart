import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import 'mock_test_attempt_screen.dart';

class MockTestListScreen extends StatefulWidget {
  final MockTestFolderModel folder;
  const MockTestListScreen({super.key, required this.folder});

  @override
  State<MockTestListScreen> createState() => _MockTestListScreenState();
}

class _MockTestListScreenState extends State<MockTestListScreen> {
  final _fs = FirestoreService();
  late final Stream<List<MockTestModel>> _stream = _fs.streamMockTests(widget.folder.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.examName)),
      body: StreamBuilder<List<MockTestModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final tests = snap.data!;
          if (tests.isEmpty) return const EmptyView('No mock test in this folder yet');
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: tests.length,
            itemBuilder: (context, i) {
              final t = tests[i];
              return DepthCard(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestAttemptScreen(test: t))),
                child: ListTile(
                  leading: const Text('📝', style: TextStyle(fontSize: 22)),
                  title: Text(t.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${t.questions.length} questions', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
