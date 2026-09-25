import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import 'mock_test_list_screen.dart';

class MockTestsScreen extends StatefulWidget {
  const MockTestsScreen({super.key});

  @override
  State<MockTestsScreen> createState() => _MockTestsScreenState();
}

class _MockTestsScreenState extends State<MockTestsScreen> {
  final _fs = FirestoreService();
  late Stream<List<MockTestFolderModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamMockFolders();
  }

  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamMockFolders());
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mock Tests')),
      body: StreamBuilder<List<MockTestFolderModel>>(
        stream: _stream,
        builder: (context, snap) {
          Widget content;
          if (snap.hasError) {
            content = PullableMessage(child: ErrorView(error: snap.error));
          } else if (!snap.hasData) {
            content = const PullableMessage(child: LoadingView());
          } else if (snap.data!.isEmpty) {
            content = const PullableMessage(child: EmptyView('No mock test folder created yet'));
          } else {
            final folders = snap.data!;
            content = ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: folders.length,
              itemBuilder: (context, i) {
                final f = folders[i];
                return DepthCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestListScreen(folder: f))),
                  child: ListTile(
                    leading: const Text('📝', style: TextStyle(fontSize: 22)),
                    title: Text(f.examName, style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                );
              },
            );
          }
          return RefreshIndicator(onRefresh: _refresh, child: content);
        },
      ),
    );
  }
}
