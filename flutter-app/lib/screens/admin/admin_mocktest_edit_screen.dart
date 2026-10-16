import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/mcq_bulk_parser.dart';
import 'admin_mock_subject_widgets.dart';

import '../../app_colors.dart';

/// Admin: edit any published mock test (title, time, marks, every question)
/// and move it to another folder. A folder decides who can see the test
/// (Free, or one/two paid batches), so moving = transferring to a batch.
class AdminMockTestEditScreen extends StatefulWidget {
  final MockTestModel test;
  const AdminMockTestEditScreen({super.key, required this.test});

  @override
  State<AdminMockTestEditScreen> createState() => _AdminMockTestEditScreenState();
}

class _AdminMockTestEditScreenState extends State<AdminMockTestEditScreen> {
  final _fs = FirestoreService();
  late final Stream<List<MockTestFolderModel>> _foldersStream = _fs.streamMockFolders();
  late final Stream<List<BatchModel>> _batchesStream = _fs.streamBatches();
  late final TextEditingController _title;
  late final TextEditingController _minutes;
  late final TextEditingController _marks;
  late final TextEditingController _neg;
  late final TextEditingController _subject;
  final _bulkCtrl = TextEditingController();
  late List<MockQuestion> _qs;
  late String _folderId;
  List<String> _bulkErrors = [];
  bool _saving = false;
  bool _dirty = false;
  // Reasoning format: automatic for subject Reasoning, or switched on by hand.
  bool _forceReasoning = false;
  bool get _reasoningMode => _forceReasoning || isDirectionsSubject(_subject.text);

  @override
  void initState() {
    super.initState();
    final t = widget.test;
    _title = TextEditingController(text: t.title);
    _minutes = TextEditingController(text: '${t.durationMinutes > 0 ? t.durationMinutes : 60}');
    _marks = TextEditingController(text: _num(t.marksPerQuestion));
    _neg = TextEditingController(text: _num(t.negativeMarks));
    _subject = TextEditingController(text: t.subject);
    _qs = List<MockQuestion>.from(t.questions);
    _folderId = t.folderId;
    _subject.addListener(_onSubjectChanged);
  }

  void _onSubjectChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subject.removeListener(_onSubjectChanged);
    _title.dispose();
    _minutes.dispose();
    _marks.dispose();
    _neg.dispose();
    _subject.dispose();
    _bulkCtrl.dispose();
    super.dispose();
  }

  String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, labelStyle: TextStyle(color: AppC.muted));

  // ---- questions ----

  Future<void> _editQuestion(int? index) async {
    final result = await showDialog<MockQuestion>(
      context: context,
      builder: (_) => _QuestionDialog(initial: index == null ? null : _qs[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      _dirty = true;
      if (index == null) {
        _qs.add(result);
      } else {
        _qs[index] = result;
      }
    });
  }

  void _deleteQuestion(int i) {
    setState(() {
      _qs.removeAt(i);
      _dirty = true;
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
    final r = parseBulkMcqs(_bulkCtrl.text, reasoning: _reasoningMode);
    if (!r.ok) {
      setState(() => _bulkErrors = r.errors);
      return;
    }
    if (_qs.length + r.questions.length > kMaxQuestionsPerTest) {
      setState(() => _bulkErrors = ['One test can have at most $kMaxQuestionsPerTest questions (this one has ${_qs.length}).']);
      return;
    }
    setState(() {
      _qs.addAll(r.questions);
      _bulkCtrl.clear();
      _bulkErrors = [];
      _dirty = true;
    });
    _snack('${r.questions.length} questions added. Tap Save to keep them.');
  }

  // ---- save ----

  Future<void> _save() async {
    if (_saving) return;
    final minutes = int.tryParse(_minutes.text.trim());
    final marks = double.tryParse(_marks.text.trim().replaceAll(',', '.'));
    final neg = double.tryParse(_neg.text.trim().replaceAll(',', '.'));
    if (_title.text.trim().isEmpty) {
      _snack('Test title cannot be empty.');
      return;
    }
    if (_qs.isEmpty) {
      _snack('A test needs at least 1 question.');
      return;
    }
    if (minutes == null || minutes < 1 || minutes > 300) {
      _snack('Enter the test time in minutes (1 to 300).');
      return;
    }
    if (marks == null || marks <= 0 || marks > 100) {
      _snack('Marks per question must be more than 0.');
      return;
    }
    if (neg == null || neg < 0 || neg > marks) {
      _snack('Negative marks must be 0 or more, and not more than the marks of a correct answer.');
      return;
    }

    final updated = MockTestModel(
      id: widget.test.id,
      folderId: _folderId,
      title: _title.text.trim(),
      questions: [..._qs],
      durationMinutes: minutes,
      marksPerQuestion: marks,
      negativeMarks: neg,
      subject: _subject.text.trim(),
    );
    if (utf8.encode(jsonEncode(updated.toMap())).length > 900000) {
      _snack('This test is too big to save. Remove some questions or shorten explanations.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _fs.saveMockTest(updated);
      _dirty = false;
      if (!mounted) return;
      _snack('Test updated.');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('Could not save: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _askLeave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Discard changes?', style: TextStyle(color: AppC.text)),
        content: Text('You have unsaved changes.', style: TextStyle(color: AppC.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  // ---- UI ----

  String _folderLabel(MockTestFolderModel f, Map<String, String> batchNames) {
    if (f.batchIds.isEmpty) return '${f.examName}  (FREE)';
    final names = f.batchIds.map((id) => batchNames[id] ?? 'deleted batch').join(', ');
    return '${f.examName}  (Batch: $names)';
  }

  Widget _folderPicker() {
    return StreamBuilder<List<MockTestFolderModel>>(
      stream: _foldersStream,
      builder: (context, fSnap) {
        return StreamBuilder<List<BatchModel>>(
          stream: _batchesStream,
          builder: (context, bSnap) {
            final folders = fSnap.data ?? <MockTestFolderModel>[];
            final names = {for (final b in bSnap.data ?? <BatchModel>[]) b.id: b.title};
            final valid = folders.any((f) => f.id == _folderId) ? _folderId : null;
            final cur = folders.where((f) => f.id == _folderId).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folder (who can see this test)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: valid,
                  hint: Text('Choose folder', style: TextStyle(color: AppC.muted)),
                  dropdownColor: AppC.card,
                  items: folders.map((f) => DropdownMenuItem(value: f.id, child: Text(_folderLabel(f, names), style: TextStyle(color: AppC.text, fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _folderId = v;
                      _dirty = true;
                    });
                  },
                ),
                if (_folderId != widget.test.folderId && cur.isNotEmpty)
                  Text(
                    cur.first.batchIds.isEmpty
                        ? 'After Save, this test will be FREE for all students.'
                        : 'After Save, only students of the batch(es) shown above can open this test.',
                    style: TextStyle(color: AppC.orange, fontSize: 12),
                  ),
                Text('To put a test in another batch: move it to a folder that is added to that batch (set this in the Mock Tests tab).', style: TextStyle(color: AppC.muted, fontSize: 11)),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _askLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit mock test'),
          actions: [TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'))],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _title, onChanged: (_) => _dirty = true, style: TextStyle(color: AppC.text), decoration: _dec('Test title')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _minutes, onChanged: (_) => _dirty = true, keyboardType: TextInputType.number, style: TextStyle(color: AppC.text), decoration: _dec('Time (minutes)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _marks, onChanged: (_) => _dirty = true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppC.text), decoration: _dec('Marks / question'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _neg, onChanged: (_) => _dirty = true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppC.text), decoration: _dec('Negative marks'))),
            ]),
            const SizedBox(height: 12),
            _folderPicker(),
            const SizedBox(height: 10),
            MockSubjectField(controller: _subject, folderId: _folderId.isEmpty ? null : _folderId, onChanged: (_) => _dirty = true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Note: if students have already taken this test, changing answers, marks or the number of questions will not change their old scores and ranks. Only new attempts use the new version.',
                style: TextStyle(color: AppC.muted, fontSize: 11),
              ),
            ),
            Divider(color: AppC.divider, height: 28),
            Row(children: [
              Expanded(child: Text('Questions (${_qs.length})', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold))),
              OutlinedButton.icon(onPressed: () => _editQuestion(null), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
            ]),
            for (var i = 0; i < _qs.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('${i + 1}', style: TextStyle(color: AppC.muted)),
                title: Text(_qs[i].text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontSize: 13)),
                subtitle: Text(
                  'Answer ${String.fromCharCode(65 + (_qs[i].correctIndex.clamp(0, 3) as int))}  \u2022  ${_qs[i].textHi.isNotEmpty ? 'Hindi \u2713' : 'English only'}  \u2022  ${_qs[i].explanation.isNotEmpty ? 'Explanation \u2713' : 'No explanation'}${(_qs[i].passage.isNotEmpty || _qs[i].passageImage.isNotEmpty) ? '  \u2022  Directions \u2713' : ''}${_qs[i].passageImage.isNotEmpty ? '  \u2022  Image \u2713' : ''}',
                  style: TextStyle(color: AppC.muted, fontSize: 10),
                ),
                onTap: () => _editQuestion(i),
                trailing: IconButton(icon: Icon(Icons.delete, color: AppC.red, size: 18), onPressed: () => _deleteQuestion(i)),
              ),
            Divider(color: AppC.divider, height: 28),
            Text('Add many questions at once (10 to 100)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
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
                  ? 'Directions format (Reasoning / Quant DI): Directions first, then an optional IMG: picture line (use the Upload DI image button), then its questions (Q: A: B: C: D: ANS: EXP:), then a ------ line. Same as in the Mock Tests tab.'
                  : 'Same Q: A: B: C: D: ANS: EXP: format as in the Mock Tests tab.',
              style: TextStyle(color: AppC.muted, fontSize: 11),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _reasoningMode ? (isQuantSubject(_subject.text) ? kDiBulkTemplate : kReasoningBulkTemplate) : kBulkTemplate));
                  _snack('Sample format copied.');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(_reasoningMode ? 'Copy Directions / DI sample format' : 'Copy sample format'),
              ),
            ),
            const SizedBox(height: 6),
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
            TextField(controller: _bulkCtrl, minLines: 4, maxLines: 12, style: TextStyle(color: AppC.text, fontSize: 13), decoration: InputDecoration(hintText: 'Paste questions here', hintStyle: TextStyle(color: AppC.muted), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _bulkAdd, icon: const Icon(Icons.playlist_add), label: const Text('Check and add')),
            for (final e in _bulkErrors.take(10)) Padding(padding: const EdgeInsets.only(top: 3), child: Text('\u2022 $e', style: TextStyle(color: AppC.orange, fontSize: 12))),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
              child: const Text('Save changes'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// One question: English, Hindi (optional), 4 options, correct answer,
/// explanation (optional, English and Hindi).
class _QuestionDialog extends StatefulWidget {
  final MockQuestion? initial;
  const _QuestionDialog({this.initial});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController _q;
  late final TextEditingController _qHi;
  late final TextEditingController _exp;
  late final TextEditingController _expHi;
  late final TextEditingController _pass;
  late final TextEditingController _passHi;
  late final TextEditingController _img;
  late final List<TextEditingController> _o;
  late final List<TextEditingController> _oHi;
  late int _correct;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _q = TextEditingController(text: q?.text ?? '');
    _qHi = TextEditingController(text: q?.textHi ?? '');
    _exp = TextEditingController(text: q?.explanation ?? '');
    _expHi = TextEditingController(text: q?.explanationHi ?? '');
    _pass = TextEditingController(text: q?.passage ?? '');
    _passHi = TextEditingController(text: q?.passageHi ?? '');
    _img = TextEditingController(text: q?.passageImage ?? '');
    _o = List.generate(4, (i) => TextEditingController(text: (q != null && i < q.options.length) ? q.options[i] : ''));
    _oHi = List.generate(4, (i) => TextEditingController(text: (q != null && i < q.optionsHi.length) ? q.optionsHi[i] : ''));
    _correct = (q?.correctIndex ?? 0).clamp(0, 3) as int;
  }

  @override
  void dispose() {
    for (final c in [_q, _qHi, _exp, _expHi, _pass, _passHi, _img, ..._o, ..._oHi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    if (_q.text.trim().isEmpty || _o.any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Fill in the English question and all 4 English options.');
      return;
    }
    final hiTyped = _oHi.where((c) => c.text.trim().isNotEmpty).length;
    if (hiTyped != 0 && hiTyped != 4) {
      setState(() => _error = 'Hindi options: fill all 4, or leave all 4 empty.');
      return;
    }
    if (hiTyped == 4 && _qHi.text.trim().isEmpty) {
      setState(() => _error = 'Hindi options are filled, so the Hindi question is needed too.');
      return;
    }
    final imgT = _img.text.trim();
    if (imgT.isNotEmpty && !imgT.toLowerCase().startsWith('http')) {
      setState(() => _error = 'DI image link must start with https://');
      return;
    }
    Navigator.pop(
      context,
      MockQuestion(
        text: _q.text.trim(),
        options: _o.map((c) => c.text.trim()).toList(),
        correctIndex: _correct,
        textHi: _qHi.text.trim(),
        optionsHi: hiTyped == 4 ? _oHi.map((c) => c.text.trim()).toList() : <String>[],
        explanation: _exp.text.trim(),
        explanationHi: _expHi.text.trim(),
        passage: _pass.text.trim(),
        passageHi: _passHi.text.trim(),
        passageImage: imgT,
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: c, minLines: 1, maxLines: lines, style: TextStyle(color: AppC.text, fontSize: 13), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: AppC.muted), isDense: true)),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppC.card,
      insetPadding: const EdgeInsets.all(12),
      title: Text(widget.initial == null ? 'Add question' : 'Edit question', style: TextStyle(color: AppC.text)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_pass, 'Directions / information (English, optional)', lines: 6),
              _field(_img, 'DI image link (https://..., optional)'),
              _field(_q, 'Question (English)', lines: 4),
              for (var i = 0; i < 4; i++)
                Row(children: [
                  Radio<int>(value: i, groupValue: _correct, activeColor: AppC.accent, onChanged: (v) => setState(() => _correct = v ?? 0)),
                  Expanded(child: _field(_o[i], 'Option ${String.fromCharCode(65 + i)}')),
                ]),
              Text('Radio = correct answer', style: TextStyle(color: AppC.muted, fontSize: 11)),
              const SizedBox(height: 8),
              _field(_exp, 'Explanation (English, optional)', lines: 4),
              Divider(color: AppC.divider),
              Text('Hindi (optional)', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _field(_passHi, 'Directions / information (Hindi)', lines: 6),
              _field(_qHi, 'Question (Hindi)', lines: 4),
              for (var i = 0; i < 4; i++) _field(_oHi[i], 'Option ${String.fromCharCode(65 + i)} (Hindi)'),
              _field(_expHi, 'Explanation (Hindi)', lines: 4),
              if (_error != null) Text(_error!, style: TextStyle(color: AppC.orange, fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _ok, child: const Text('OK')),
      ],
    );
  }
}
