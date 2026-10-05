import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../services/mcq_bulk_parser.dart';

const _navy = Color(0xFF081136);
const _cardBg = Color(0xFF101D57);
const _gold = Color(0xFFFFFF29);

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
  final _bulkCtrl = TextEditingController();
  late List<MockQuestion> _qs;
  late String _folderId;
  List<String> _bulkErrors = [];
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final t = widget.test;
    _title = TextEditingController(text: t.title);
    _minutes = TextEditingController(text: '${t.durationMinutes > 0 ? t.durationMinutes : 60}');
    _marks = TextEditingController(text: _num(t.marksPerQuestion));
    _neg = TextEditingController(text: _num(t.negativeMarks));
    _qs = List<MockQuestion>.from(t.questions);
    _folderId = t.folderId;
  }

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    _marks.dispose();
    _neg.dispose();
    _bulkCtrl.dispose();
    super.dispose();
  }

  String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey));

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

  void _bulkAdd() {
    final r = parseBulkMcqs(_bulkCtrl.text);
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
        backgroundColor: _navy,
        title: const Text('Discard changes?', style: TextStyle(color: Colors.white)),
        content: const Text('You have unsaved changes.', style: TextStyle(color: Colors.grey)),
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
                const Text('Folder (who can see this test)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: valid,
                  hint: const Text('Choose folder', style: TextStyle(color: Colors.grey)),
                  dropdownColor: _navy,
                  items: folders.map((f) => DropdownMenuItem(value: f.id, child: Text(_folderLabel(f, names), style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
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
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                const Text('To put a test in another batch: move it to a folder that is added to that batch (set this in the Mock Tests tab).', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
            TextField(controller: _title, onChanged: (_) => _dirty = true, style: const TextStyle(color: Colors.white), decoration: _dec('Test title')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _minutes, onChanged: (_) => _dirty = true, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _dec('Time (minutes)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _marks, onChanged: (_) => _dirty = true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Marks / question'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _neg, onChanged: (_) => _dirty = true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Negative marks'))),
            ]),
            const SizedBox(height: 12),
            _folderPicker(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'Note: if students have already taken this test, changing answers, marks or the number of questions will not change their old scores and ranks. Only new attempts use the new version.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
            const Divider(color: Colors.grey, height: 28),
            Row(children: [
              Expanded(child: Text('Questions (${_qs.length})', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold))),
              OutlinedButton.icon(onPressed: () => _editQuestion(null), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
            ]),
            for (var i = 0; i < _qs.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('${i + 1}', style: const TextStyle(color: Colors.grey)),
                title: Text(_qs[i].text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text(
                  'Answer ${String.fromCharCode(65 + (_qs[i].correctIndex.clamp(0, 3) as int))}  \u2022  ${_qs[i].textHi.isNotEmpty ? 'Hindi \u2713' : 'English only'}  \u2022  ${_qs[i].explanation.isNotEmpty ? 'Explanation \u2713' : 'No explanation'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                onTap: () => _editQuestion(i),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deleteQuestion(i)),
              ),
            const Divider(color: Colors.grey, height: 28),
            const Text('Add many questions at once (10 to 100)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Same Q: A: B: C: D: ANS: EXP: format as in the Mock Tests tab.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 6),
            TextField(controller: _bulkCtrl, minLines: 4, maxLines: 12, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: 'Paste questions here', hintStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _bulkAdd, icon: const Icon(Icons.playlist_add), label: const Text('Check and add')),
            for (final e in _bulkErrors.take(10)) Padding(padding: const EdgeInsets.only(top: 3), child: Text('\u2022 $e', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
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
    _o = List.generate(4, (i) => TextEditingController(text: (q != null && i < q.options.length) ? q.options[i] : ''));
    _oHi = List.generate(4, (i) => TextEditingController(text: (q != null && i < q.optionsHi.length) ? q.optionsHi[i] : ''));
    _correct = (q?.correctIndex ?? 0).clamp(0, 3) as int;
  }

  @override
  void dispose() {
    for (final c in [_q, _qHi, _exp, _expHi, ..._o, ..._oHi]) {
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
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: c, minLines: 1, maxLines: lines, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), isDense: true)),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _navy,
      insetPadding: const EdgeInsets.all(12),
      title: Text(widget.initial == null ? 'Add question' : 'Edit question', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_q, 'Question (English)', lines: 4),
              for (var i = 0; i < 4; i++)
                Row(children: [
                  Radio<int>(value: i, groupValue: _correct, activeColor: _gold, onChanged: (v) => setState(() => _correct = v ?? 0)),
                  Expanded(child: _field(_o[i], 'Option ${String.fromCharCode(65 + i)}')),
                ]),
              const Text('Radio = correct answer', style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),
              _field(_exp, 'Explanation (English, optional)', lines: 4),
              const Divider(color: Colors.grey),
              const Text('Hindi (optional)', style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _field(_qHi, 'Question (Hindi)', lines: 4),
              for (var i = 0; i < 4; i++) _field(_oHi[i], 'Option ${String.fromCharCode(65 + i)} (Hindi)'),
              _field(_expHi, 'Explanation (Hindi)', lines: 4),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
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
