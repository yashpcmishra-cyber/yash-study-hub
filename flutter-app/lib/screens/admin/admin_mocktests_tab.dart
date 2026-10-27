import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../services/image_upload_service.dart';
import '../../services/mcq_bulk_parser.dart';
import 'admin_free_mcq_import.dart';
import 'admin_copy_folder_dialog.dart';
import 'admin_mock_subject_widgets.dart';
import 'admin_mocktest_edit_screen.dart';
import 'admin_rename_folder_dialog.dart';
import 'admin_reorder_list.dart';
import '../../app_colors.dart';

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
  final _subject = TextEditingController(); // optional subject folder inside the exam folder
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
  // Reasoning format (Directions / puzzle info before the questions). It is
  // used automatically when the subject is Reasoning; the switch can force
  // it for a test whose subject has another name.
  bool _forceReasoning = false;
  bool get _reasoningMode => _forceReasoning || isDirectionsSubject(_subject.text);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Redraw the paste box instructions when the subject changes.
    _subject.addListener(_onSubjectChanged);
  }

  void _onSubjectChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subject.removeListener(_onSubjectChanged);
    _newFolderName.dispose();
    _testTitle.dispose();
    _subject.dispose();
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
        backgroundColor: AppC.card,
        title: Text(title, style: TextStyle(color: AppC.text)),
        content: Text(message, style: TextStyle(color: AppC.muted)),
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

  final _imageUpload = ImageUploadService();
  bool _uploadingImg = false;

  // Pick the DI graph from the phone gallery, upload it (same GitHub images
  // repo as banners/icons, so no Firebase Storage / paid plan) and write the
  // "IMG: link" line into the paste box at the cursor.
  Future<void> _uploadDiImage() async {
    if (_uploadingImg) return;
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (img == null) return;
    setState(() => _uploadingImg = true);
    try {
      final url = await _imageUpload.uploadImage(File(img.path));
      final line = 'IMG: $url';
      final text = _bulkCtrl.text;
      var pos = _bulkCtrl.selection.baseOffset;
      if (pos < 0 || pos > text.length) pos = text.length;
      final before = text.substring(0, pos);
      final after = text.substring(pos);
      final pre = (before.isEmpty || before.endsWith('\n')) ? '' : '\n';
      final inserted = '$pre$line\n';
      _bulkCtrl.text = '$before$inserted$after';
      _bulkCtrl.selection = TextSelection.collapsed(offset: before.length + inserted.length);
      await Clipboard.setData(ClipboardData(text: line));
      _snack('Image uploaded. The IMG: line was added to the paste box (and copied).');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploadingImg = false);
    }
  }

  void _bulkAdd() {
    final result = parseBulkMcqs(_bulkCtrl.text, reasoning: _reasoningMode);
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

  // Copy every question of the Free MCQs set(s) the admin ticks into the test being built.
  Future<void> _importFromFreeMcqs() async {
    final res = await showFreeMcqImportSheet(context);
    if (res == null || !mounted) return;
    final seen = _draftQuestions.map((q) => q.text.trim().toLowerCase()).toSet();
    final fresh = res.questions.where((q) => seen.add(q.text.trim().toLowerCase())).toList();
    final skipped = res.questions.length - fresh.length;
    if (_draftQuestions.length + fresh.length > kMaxQuestionsPerTest) {
      _snack('One test can have at most $kMaxQuestionsPerTest questions (you already have ${_draftQuestions.length}). Pick fewer sets.');
      return;
    }
    setState(() {
      _draftQuestions.addAll(fresh);
      if (_testTitle.text.trim().isEmpty && res.suggestedTitle.isNotEmpty) _testTitle.text = res.suggestedTitle;
      if (_subject.text.trim().isEmpty && res.suggestedSubject.isNotEmpty) _subject.text = res.suggestedSubject;
    });
    _snack('${fresh.length} MCQs copied from ${res.setCount} set(s)${skipped > 0 ? ' ($skipped repeats skipped)' : ''}. Now choose the folder and publish.');
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
      subject: _subject.text.trim(),
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

  Future<void> _renameFolder(String folderId, String currentName) async {
    final newName = await showRenameFolderDialog(context, currentName: currentName, title: 'Rename exam folder');
    if (newName == null) return;
    try {
      await _fs.renameMockFolder(folderId, newName);
      _snack('Folder renamed.');
    } catch (e) {
      _snack('Rename failed: $e');
    }
  }

  // Copies this exam folder (all tests, or just one subject folder of it) into
  // other paid batches and / or Free Mock Tests in one go. The copy is
  // independent of the original.
  Future<void> _copyFolder(MockTestFolderModel f) async {
    List<BatchModel> batches;
    List<String> subjects;
    try {
      batches = await _fs.streamBatches().first.timeout(const Duration(seconds: 12));
      final tests = await _fs.streamMockTests(f.id).first.timeout(const Duration(seconds: 12));
      subjects = groupMockTestsBySubject(tests).groups.map((g) => g.name).toList();
    } catch (_) {
      _snack('Could not load the data \u2014 check your internet and try again.');
      return;
    }
    if (!mounted) return;
    final choice = await showCopyFolderDialog(
      context,
      folderName: f.examName,
      freeLabel: 'Free Mock Tests',
      batches: batches, // every batch type can hold mock tests
      alreadyIn: f.isFree ? <String>{kCopyFreeDest} : f.batchIds.toSet(),
      subjects: subjects,
    );
    if (choice == null) return;
    _snack('Copying "${f.examName}" ...');
    try {
      final n = await _fs.copyMockFolder(f.id, choice.destinations, onlySubject: choice.subject);
      _snack('Copied "${f.examName}" ($n tests) to ${choice.destinations.length} place(s).');
    } catch (e) {
      _snack('Copy failed: $e');
    }
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
  // No batch chosen = FREE folder. At most 3 batches (keeps the Firestore
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
                style: TextStyle(color: chosen.isEmpty ? AppC.green : AppC.orange, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text('Tap a batch to add / remove it (max 3). No batch = free.', style: TextStyle(color: AppC.muted, fontSize: 11)),
              const SizedBox(height: 4),
              if (batches.isEmpty)
                Text('No paid batch created yet', style: TextStyle(color: AppC.muted, fontSize: 12))
              else
                Wrap(
                  spacing: 6,
                  children: batches.map((b) {
                    final on = chosen.contains(b.id);
                    return FilterChip(
                      label: Text(b.mockOnly ? '📝 ${b.title}' : b.title, style: TextStyle(color: on ? AppC.onGold : AppC.text, fontSize: 12)),
                      selected: on,
                      selectedColor: AppC.gold,
                      checkmarkColor: AppC.onGold,
                      backgroundColor: AppC.card2,
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
      if (next.length >= 3) {
        _snack('A folder can be in at most 3 batches. Remove one first.');
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
        Text('1. Choose an exam folder or create a new one', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<MockTestFolderModel>>(
          stream: _foldersStream,
          builder: (context, snap) {
            final folders = snap.data ?? <MockTestFolderModel>[];
            final selected = folders.where((f) => f.id == _selectedFolderId).toList();
            final folderRow = Row(children: [
              Expanded(
                child: DropdownButton<String>(
                  hint: Text('Choose folder', style: TextStyle(color: AppC.muted)),
                  value: _validId(_selectedFolderId, folders.map((f) => f.id)),
                  dropdownColor: AppC.card,
                  isExpanded: true,
                  items: folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.examName, style: TextStyle(color: AppC.text)))).toList(),
                  onChanged: (v) => setState(() => _selectedFolderId = v),
                ),
              ),
              if (_selectedFolderId != null && selected.isNotEmpty) ...[
                IconButton(tooltip: 'Copy this folder to other batches / Free Mocks', icon: Icon(Icons.copy_all, color: AppC.sky, size: 20), onPressed: () => _copyFolder(selected.first)),
                IconButton(tooltip: 'Rename this folder', icon: Icon(Icons.edit, color: AppC.accent, size: 20), onPressed: () => _renameFolder(selected.first.id, selected.first.examName)),
                IconButton(tooltip: 'Delete this folder', icon: Icon(Icons.delete, color: AppC.red, size: 20), onPressed: () => _deleteFolderConfirm(selected.first.id, selected.first.examName)),
              ],
            ]);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                folderRow,
                if (selected.isNotEmpty) _batchPicker(selected.first),
                if (folders.length >= 2)
                  AdminFolderOrderSection<MockTestFolderModel>(
                    items: folders,
                    idOf: (f) => f.id,
                    labelOf: (f) => f.examName,
                    onSave: (list) => _fs.saveOrder('mockTestFolders', list.map((f) => f.id).toList()),
                  ),
              ],
            );
          },
        ),
        Row(children: [
          Expanded(child: TextField(controller: _newFolderName, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'New exam folder (e.g. SSC CGL)', hintStyle: TextStyle(color: AppC.muted)))),
          IconButton(icon: Icon(Icons.add_circle, color: AppC.accent), onPressed: _createFolder),
        ]),
        Divider(color: AppC.divider),
        Text('2. Test title and subject', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        TextField(controller: _testTitle, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'e.g. SSC CGL Full Mock 1', hintStyle: TextStyle(color: AppC.muted))),
        const SizedBox(height: 10),
        MockSubjectField(controller: _subject, folderId: _selectedFolderId),
        Text('The subject stays filled for your next test (clear it if the next test has no subject).', style: TextStyle(color: AppC.muted, fontSize: 11)),
        Divider(color: AppC.divider),
        Text('3. Exam settings', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: TextField(controller: _durationCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppC.text), decoration: InputDecoration(labelText: 'Time (minutes)', labelStyle: TextStyle(color: AppC.muted)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _marksCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppC.text), decoration: InputDecoration(labelText: 'Marks / question', labelStyle: TextStyle(color: AppC.muted)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _negCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppC.text), decoration: InputDecoration(labelText: 'Negative marks', labelStyle: TextStyle(color: AppC.muted)))),
        ]),
        const SizedBox(height: 4),
        Text('Negative marks = cut for each wrong answer (0 means no negative marking). These settings stay filled for your next test.', style: TextStyle(color: AppC.muted, fontSize: 11)),
        Divider(color: AppC.divider),
        Text('4a. Add questions (one at a time)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: _qText, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'Write the question', hintStyle: TextStyle(color: AppC.muted))),
        const SizedBox(height: 8),
        ...List.generate(
          4,
          (i) => Row(children: [
            Radio<int>(value: i, groupValue: _correctIndex, activeColor: AppC.accent, onChanged: (v) => setState(() => _correctIndex = v ?? 0)),
            Expanded(child: TextField(controller: _optionCtrls[i], style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'Option ${i + 1}', hintStyle: TextStyle(color: AppC.muted)))),
          ]),
        ),
        Text('(Tap the radio button next to the correct option)', style: TextStyle(color: AppC.muted, fontSize: 11)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _addQuestionToDraft, icon: const Icon(Icons.add), label: const Text('Add question to this test')),
        Divider(color: AppC.divider, height: 30),
        Text('4b. Bulk paste (10 to 100 questions at once)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: AppC.accent,
          title: Text(_reasoningMode ? 'Format in use: DIRECTIONS / DI' : 'Format in use: Standard', style: TextStyle(color: _reasoningMode ? AppC.accent : AppC.text, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(
            isDirectionsSubject(_subject.text) ? 'Switched on automatically because the subject is Reasoning or Quant.' : 'Turns on automatically when the subject is Reasoning or Quant. Or switch it on by hand.',
            style: TextStyle(color: AppC.muted, fontSize: 11),
          ),
          value: _reasoningMode,
          onChanged: isDirectionsSubject(_subject.text) ? null : (v) => setState(() => _forceReasoning = v),
        ),
        Text(
          _reasoningMode
              ? 'Directions format (Reasoning / Quant DI): write the Directions / information first (English line, then its Hindi line, or English || Hindi on one line; start a bullet with *). For a DI graph, tap Upload DI image: an IMG: line is added at the cursor, keep it under the Directions. Then the questions of that group, each with Q: A: B: C: D: ANS: and optional EXP:. Put a line of dashes (------) after the group; the next group starts with its own Directions. The directions are shown above every question of the group in the test. Questions with no directions are fine too.'
              : 'Every question starts with Q: then options A: B: C: D:, then ANS: (A/B/C/D). EXP: (explanation) is optional. Write English || Hindi on one line for a bilingual test. Without || the text is a single language.',
          style: TextStyle(color: AppC.muted, fontSize: 11),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _reasoningMode ? (isQuantSubject(_subject.text) ? kDiBulkTemplate : kReasoningBulkTemplate) : kBulkTemplate));
              _snack(_reasoningMode ? 'Reasoning format copied. Paste it anywhere and fill in your questions.' : 'Format copied. Paste it anywhere and fill in your questions.');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(_reasoningMode ? 'Copy Directions / DI sample format' : 'Copy sample format'),
          ),
        ),
        if (_reasoningMode)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _uploadingImg ? null : _uploadDiImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_uploadingImg ? 'Uploading image...' : 'Upload DI image (adds IMG: line at cursor)'),
            ),
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _bulkCtrl,
          minLines: 6,
          maxLines: 14,
          style: TextStyle(color: AppC.text, fontSize: 13),
          decoration: InputDecoration(hintText: 'Paste your questions here', hintStyle: TextStyle(color: AppC.muted), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _bulkAdd, icon: const Icon(Icons.playlist_add), label: const Text('Check and add to this test')),
        if (_bulkErrors.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._bulkErrors.take(12).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $e', style: TextStyle(color: AppC.orange, fontSize: 12)),
              )),
          if (_bulkErrors.length > 12) Text('...and ${_bulkErrors.length - 12} more problems', style: TextStyle(color: AppC.orange, fontSize: 12)),
        ],
        Divider(color: AppC.divider, height: 30),
        Text('4c. Copy from Free MCQs', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Take the ready-made MCQs of any Free MCQs subject / month (with Hindi and explanations) into this test. You can tick several sets, and delete single questions below.', style: TextStyle(color: AppC.muted, fontSize: 11)),
        const SizedBox(height: 6),
        OutlinedButton.icon(onPressed: _importFromFreeMcqs, icon: const Icon(Icons.library_add), label: const Text('Copy from Free MCQs')),
        Divider(color: AppC.divider, height: 30),
        Text('Questions added so far: ${_draftQuestions.length}', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold)),
        ..._draftQuestions.asMap().entries.map((e) => ListTile(
              dense: true,
              leading: Text('${e.key + 1}', style: TextStyle(color: AppC.muted)),
              title: Text(e.value.text, style: TextStyle(color: AppC.text, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${e.value.textHi.isNotEmpty ? 'Hindi ✓' : 'English only'}  •  ${e.value.explanation.isNotEmpty ? 'Explanation ✓' : 'No explanation'}${(e.value.passage.isNotEmpty || e.value.passageImage.isNotEmpty) ? '  •  Directions ✓' : ''}${e.value.passageImage.isNotEmpty ? '  •  Image ✓' : ''}',
                style: TextStyle(color: AppC.muted, fontSize: 10),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: AppC.red, size: 18),
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
          Divider(color: AppC.divider, height: 30),
          Text('Published tests in this folder', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<MockTestModel>>(
            stream: _fs.streamMockTests(_selectedFolderId!),
            builder: (context, snap) {
              if (snap.hasError) return Text('Could not load: ${snap.error}', style: TextStyle(color: AppC.orange, fontSize: 12));
              if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator()));
              final tests = snap.data!;
              if (tests.isEmpty) return Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No test is published in this folder yet', style: TextStyle(color: AppC.muted, fontSize: 12)));
              return AdminReorderList<MockTestModel>(
                items: tests,
                idOf: (t) => t.id,
                onSave: (list) => _fs.saveOrder('mockTests', list.map((t) => t.id).toList()),
                contentBuilder: (context, t) => ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: Icon(Icons.quiz, color: AppC.accent, size: 20),
                          title: Text(t.title, style: TextStyle(color: AppC.text, fontSize: 13)),
                          subtitle: Text(
                              '${t.subject.isNotEmpty ? '📚 ${t.subject} • ' : ''}'
                              '${t.durationMinutes > 0 ? '${t.questions.length} questions • ${t.durationMinutes} min • +${t.marksPerQuestion} / -${t.negativeMarks}' : '${t.questions.length} questions'}',
                              style: TextStyle(color: AppC.muted, fontSize: 11),
                            ),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Move to another exam folder / subject',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.drive_file_move, color: AppC.sky, size: 18),
                              onPressed: () async {
                                final moved = await showMoveMockTestDialog(context, t);
                                if (moved) _snack('Test moved.');
                              },
                            ),
                            IconButton(
                              tooltip: 'Edit / move',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.edit, color: AppC.accent, size: 18),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminMockTestEditScreen(test: t))),
                            ),
                            IconButton(padding: const EdgeInsets.all(6), constraints: const BoxConstraints(), icon: Icon(Icons.delete, color: AppC.red, size: 18), onPressed: () => _deleteTestConfirm(t)),
                          ]),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
