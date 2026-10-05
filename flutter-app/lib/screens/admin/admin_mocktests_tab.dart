import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../services/mcq_bulk_parser.dart';
import 'admin_mocktest_edit_screen.dart';

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
  late final Stream<List<BatchModel>> _batchesStream = _fs.streamBatches();
  final _newFolderName = TextEditingController();
  String? _selectedFolderId;
  final _testTitle = TextEditingController();
  bool _publishing = false;

  // Questions being built for the test currently being created.
  final List<MockQuestion> _draftQuestions = [];
  final _qText = TextEditingController();
  final List<TextEditingController> _optionCtrls = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;

  // Exam settings - chosen by the admin for every test.
  final _durationCtrl = TextEditingController(text: '60');
  final _marksCtrl = TextEditingController(text: '1');
  final _negCtrl = TextEditingController(text: '0');

  // Bulk paste.
  final _bulkCtrl = TextEditingController();
  List<String> _bulkErrors = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _newFolderName.dispose();
    _testTitle.dispose();
    _qText.dispose();
    _durationCtrl.dispose();
    _marksCtrl.dispose();
    _negCtrl.dispose();
    _bulkCtrl.dispose();
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

  void _bulkAdd() {
    final result = parseBulkMcqs(_bulkCtrl.text);
    if (!result.ok) {
      setState(() => _bulkErrors = result.errors);
      _snack('Please fix the problems listed below the box.');
      return;
    }
    if (_draftQuestions.length + result.questions.length > kMaxQuestionsPerTest) {
      setState(() => _bulkErrors = ['One test can have at most $kMaxQuestionsPerTest questions (you already have ${_draftQuestions.length}).']);
      return;
    }
    setState(() {
      _draftQuestions.addAll(result.questions);
      _bulkCtrl.clear();
      _bulkErrors = [];
    });
    _snack('${result.questions.length} questions added to this test.');
  }

  Future<void> _publishTest() async {
    if (_publishing) return;
    if (_selectedFolderId == null || _testTitle.text.trim().isEmpty || _draftQuestions.isEmpty) {
      _snack('Folder, title, and at least 1 question are required.');
      return;
    }
    final minutes = int.tryParse(_durationCtrl.text.trim());
    final marks = double.tryParse(_marksCtrl.text.trim().replaceAll(',', '.'));
    final neg = double.tryParse(_negCtrl.text.trim().replaceAll(',', '.'));
    if (minutes == null || minutes < 1 || minutes > 300) {
      _snack('Enter the test time in minutes (1 to 300).');
      return;
    }
    if (marks == null || marks <= 0 || marks > 100) {
      _snack('Marks per question must be more than 0 (for example 1 or 2).');
      return;
    }
    if (neg == null || neg < 0 || neg > marks) {
      _snack('Negative marks must be 0 or more, and not more than the marks of a correct answer.');
      return;
    }
    final test = MockTestModel(
      id: '',
      folderId: _selectedFolderId!,
      title: _testTitle.text.trim(),
      questions: [..._draftQuestions],
      durationMinutes: minutes,
      marksPerQuestion: marks,
      negativeMarks: neg,
    );
    // Firestore documents are limited to about 1 MB.
    if (utf8.encode(jsonEncode(test.toMap())).length > 900000) {
      _snack('This test is too big to save. Please make it with fewer questions or shorter explanations.');
      return;
    }
    setState(() => _publishing = true);
    try {
      await _fs.saveMockTest(test);
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

  // Paid batches for the chosen folder: tap a batch to add / remove it.
  // No batch chosen = FREE folder. At most 2 batches (keeps the Firestore
  // rule simple and fast).
  Widget _batchPicker(MockTestFolderModel f) {
    return StreamBuilder<List<BatchModel>>(
      stream: _batchesStream,
      builder: (context, snap) {
        final batches = snap.data ?? <BatchModel>[];
        final existing = batches.map((b) => b.id).toSet();
        final chosen = f.batchIds;
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chosen.isEmpty ? 'Shown in: FREE Mock Tests (all students)' : 'Shown ONLY inside the paid batch(es) selected below',
                style: TextStyle(color: chosen.isEmpty ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Text('Tap a batch to add / remove it (max 2). No batch = free.', style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 4),
              if (batches.isEmpty)
                const Text('No paid batch created yet', style: TextStyle(color: Colors.grey, fontSize: 12))
              else
                Wrap(
                  spacing: 6,
                  children: batches.map((b) {
                    final on = chosen.contains(b.id);
                    return FilterChip(
                      label: Text(b.mockOnly ? '📝 ${b.title}' : b.title, style: TextStyle(color: on ? const Color(0xFF081136) : Colors.white, fontSize: 12)),
                      selected: on,
                      selectedColor: const Color(0xFFFFFF29),
                      checkmarkColor: const Color(0xFF081136),
                      backgroundColor: const Color(0xFF101D57),
                      onSelected: (v) => _toggleBatch(f, b.id, v, existing),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleBatch(MockTestFolderModel f, String batchId, bool on, Set<String> existing) async {
    // Batches that were deleted meanwhile are dropped from the list.
    final next = f.batchIds.where(existing.contains).toList();
    if (on) {
      if (next.contains(batchId)) return;
      if (next.length >= 2) {
        _snack('A folder can be in at most 2 batches. Remove one first.');
        return;
      }
      next.add(batchId);
    } else {
      next.remove(batchId);
      if (next.isEmpty) {
        final ok = await _confirm('Make folder free?', 'No batch will be left, so "${f.examName}" becomes FREE and every student can open its tests.');
        if (!ok) return;
      }
    }
    try {
      await _fs.setMockFolderBatches(f.id, next);
    } catch (e) {
      _snack('Could not update: $e');
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
            final folderRow = Row(children: [
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [folderRow, if (selected.isNotEmpty) _batchPicker(selected.first)],
            );
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
        const Text('3. Exam settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: TextField(controller: _durationCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Time (minutes)', labelStyle: TextStyle(color: Colors.grey)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _marksCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Marks / question', labelStyle: TextStyle(color: Colors.grey)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _negCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Negative marks', labelStyle: TextStyle(color: Colors.grey)))),
        ]),
        const SizedBox(height: 4),
        const Text('Negative marks = cut for each wrong answer (0 means no negative marking). These settings stay filled for your next test.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        const Divider(color: Colors.grey),
        const Text('4a. Add questions (one at a time)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        const Divider(color: Colors.grey, height: 30),
        const Text('4b. Bulk paste (10 to 100 questions at once)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Every question starts with Q: then options A: B: C: D:, then ANS: (A/B/C/D). EXP: (explanation) is optional. Write English || Hindi on one line for a bilingual test. Without || the text is a single language.',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: kBulkTemplate));
              _snack('Format copied. Paste it anywhere and fill in your questions.');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy sample format'),
          ),
        ),
        TextField(
          controller: _bulkCtrl,
          minLines: 6,
          maxLines: 14,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(hintText: 'Paste your questions here', hintStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _bulkAdd, icon: const Icon(Icons.playlist_add), label: const Text('Check and add to this test')),
        if (_bulkErrors.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._bulkErrors.take(12).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $e', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              )),
          if (_bulkErrors.length > 12) Text('...and ${_bulkErrors.length - 12} more problems', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ],
        const Divider(color: Colors.grey, height: 30),
        Text('Questions added so far: ${_draftQuestions.length}', style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold)),
        ..._draftQuestions.asMap().entries.map((e) => ListTile(
              dense: true,
              leading: Text('${e.key + 1}', style: const TextStyle(color: Colors.grey)),
              title: Text(e.value.text, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${e.value.textHi.isNotEmpty ? 'Hindi ✓' : 'English only'}  •  ${e.value.explanation.isNotEmpty ? 'Explanation ✓' : 'No explanation'}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
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
                          subtitle: Text(
                              t.durationMinutes > 0 ? '${t.questions.length} questions • ${t.durationMinutes} min • +${t.marksPerQuestion} / -${t.negativeMarks}' : '${t.questions.length} questions',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Edit / move',
                              icon: const Icon(Icons.edit, color: Color(0xFFFFFF29), size: 18),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminMockTestEditScreen(test: t))),
                            ),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deleteTestConfirm(t)),
                          ]),
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
