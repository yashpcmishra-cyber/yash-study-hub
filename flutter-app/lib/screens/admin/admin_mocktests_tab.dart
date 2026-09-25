import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';

class AdminMockTestsTab extends StatefulWidget {
  const AdminMockTestsTab({super.key});
  @override
  State<AdminMockTestsTab> createState() => _AdminMockTestsTabState();
}

// AutomaticKeepAliveClientMixin: the questions you are building (and
// everything you typed) are NOT lost when you switch to another tab and
// come back.
class _AdminMockTestsTabState extends State<AdminMockTestsTab> with AutomaticKeepAliveClientMixin {
  final _fs = FirestoreService();
  late final Stream<List<MockTestFolderModel>> _foldersStream = _fs.streamMockFolders();
  final _newFolderName = TextEditingController();
  String? _selectedFolderId;
  final _testTitle = TextEditingController();
  bool _publishing = false;

  // Questions being built for the test currently being created.
  final List<MockQuestion> _draftQuestions = [];
  final _qText = TextEditingController();
  final List<TextEditingController> _optionCtrls = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _newFolderName.dispose();
    _testTitle.dispose();
    _qText.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // A dropdown crashes (in debug) if its value is not in its list, so
  // anything that is no longer in the list is treated as "nothing chosen".
  String? _validId(String? id, Iterable<String> ids) => (id != null && ids.contains(id)) ? id : null;

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF081136),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _createFolder() async {
    if (_newFolderName.text.trim().isEmpty) return;
    try {
      await _fs.addMockFolder(_newFolderName.text.trim());
      _newFolderName.clear();
      _snack('Folder created.');
    } catch (e) {
      _snack('Could not create the folder: $e');
    }
  }

  void _addQuestionToDraft() {
    if (_qText.text.trim().isEmpty || _optionCtrls.any((c) => c.text.trim().isEmpty)) {
      _snack('Fill in the question and all four options.');
      return;
    }
    setState(() {
      _draftQuestions.add(MockQuestion(text: _qText.text.trim(), options: _optionCtrls.map((c) => c.text.trim()).toList(), correctIndex: _correctIndex));
      _qText.clear();
      for (final c in _optionCtrls) {
        c.clear();
      }
      _correctIndex = 0;
    });
  }

  Future<void> _publishTest() async {
    if (_publishing) return;
    if (_selectedFolderId == null || _testTitle.text.trim().isEmpty || _draftQuestions.isEmpty) {
      _snack('Folder, title, and at least 1 question are required.');
      return;
    }
    setState(() => _publishing = true);
    try {
      await _fs.saveMockTest(MockTestModel(id: '', folderId: _selectedFolderId!, title: _testTitle.text.trim(), questions: [..._draftQuestions]));
      if (mounted) {
        setState(() {
          _draftQuestions.clear();
          _testTitle.clear();
        });
      }
      _snack('Mock test published!');
    } catch (e) {
      // The questions stay on screen, nothing is lost — just try again.
      _snack('Could not publish the test: $e');
    }
    if (mounted) setState(() => _publishing = false);
  }

  Future<void> _deleteFolderConfirm(String folderId, String folderName) async {
    final ok = await _confirm('Delete folder?', 'Delete the folder "$folderName"? All mock tests inside it will be deleted too. This cannot be undone.');
    if (!ok) return;
    try {
      await _fs.deleteMockFolder(folderId);
      if (mounted) setState(() => _selectedFolderId = null);
      _snack('Folder deleted.');
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Future<void> _deleteTestConfirm(MockTestModel t) async {
    final ok = await _confirm('Delete test?', 'Delete "${t.title}"? Past student attempts (in the Attempts tab) are not deleted \u2014 only the test is removed.');
    if (!ok) return;
    try {
      await _fs.deleteMockTest(t.id);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('1. Choose an exam folder or create a new one', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<MockTestFolderModel>>(
          stream: _foldersStream,
          builder: (context, snap) {
            final folders = snap.data ?? <MockTestFolderModel>[];
            final selected = folders.where((f) => f.id == _selectedFolderId).toList();
            return Row(children: [
              Expanded(
                child: DropdownButton<String>(
                  hint: const Text('Choose folder', style: TextStyle(color: Colors.grey)),
                  value: _validId(_selectedFolderId, folders.map((f) => f.id)),
                  dropdownColor: const Color(0xFF081136),
                  isExpanded: true,
                  items: folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.examName, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _selectedFolderId = v),
                ),
              ),
              if (_selectedFolderId != null && selected.isNotEmpty)
                IconButton(tooltip: 'Delete this folder', icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteFolderConfirm(selected.first.id, selected.first.examName)),
            ]);
          },
        ),
        Row(children: [
          Expanded(child: TextField(controller: _newFolderName, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'New exam folder (e.g. SSC CGL)', hintStyle: TextStyle(color: Colors.grey)))),
          IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFFFFF29)), onPressed: _createFolder),
        ]),
        const Divider(color: Colors.grey),
        const Text('2. Test title', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        TextField(controller: _testTitle, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'e.g. SSC CGL Full Mock 1', hintStyle: TextStyle(color: Colors.grey))),
        const Divider(color: Colors.grey),
        const Text('3. Add questions (one at a time)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: _qText, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Write the question', hintStyle: TextStyle(color: Colors.grey))),
        const SizedBox(height: 8),
        ...List.generate(
          4,
          (i) => Row(children: [
            Radio<int>(value: i, groupValue: _correctIndex, activeColor: const Color(0xFFFFFF29), onChanged: (v) => setState(() => _correctIndex = v ?? 0)),
            Expanded(child: TextField(controller: _optionCtrls[i], style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Option ${i + 1}', hintStyle: const TextStyle(color: Colors.grey)))),
          ]),
        ),
        const Text('(Tap the radio button next to the correct option)', style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _addQuestionToDraft, icon: const Icon(Icons.add), label: const Text('Add question to this test')),
        const SizedBox(height: 10),
        Text('Questions added so far: ${_draftQuestions.length}', style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold)),
        ..._draftQuestions.asMap().entries.map((e) => ListTile(
              dense: true,
              leading: Text('${e.key + 1}', style: const TextStyle(color: Colors.grey)),
              title: Text(e.value.text, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                onPressed: () => setState(() {
                  _draftQuestions.removeAt(e.key);
                }),
              ),
            )),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _publishing ? null : _publishTest,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
          child: _publishing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publish Mock Test'),
        ),
        if (_selectedFolderId != null) ...[
          const Divider(color: Colors.grey, height: 30),
          const Text('Published tests in this folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<MockTestModel>>(
            stream: _fs.streamMockTests(_selectedFolderId!),
            builder: (context, snap) {
              if (snap.hasError) return Text('Could not load: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12));
              if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator()));
              final tests = snap.data!;
              if (tests.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No test is published in this folder yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
              return Column(
                children: tests
                    .map((t) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.quiz, color: Color(0xFFFFFF29), size: 20),
                          title: Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text('${t.questions.length} questions', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deleteTestConfirm(t)),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}
