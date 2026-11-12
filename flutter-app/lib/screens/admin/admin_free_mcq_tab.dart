import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../services/free_mcq_service.dart';
import '../../widgets/depth_card.dart';
import 'admin_free_to_mock_dialog.dart';

/// Admin Panel tab: add / edit / remove / reorder the EXAM folders shown in
/// the student-side "Free MCQs" section (SSC, UPSSSC, Railway ...).
///
/// Data lives in ONE document: freeMcqIndex/current  ->  field `exams`
/// (list of {id, name, emoji}). The weekly GitHub script reads this list
/// and builds the 25-question sets for every exam in it.
class AdminFreeMcqTab extends StatefulWidget {
  const AdminFreeMcqTab({super.key});

  @override
  State<AdminFreeMcqTab> createState() => _AdminFreeMcqTabState();
}

class _AdminFreeMcqTabState extends State<AdminFreeMcqTab> {
  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _ref => _db.collection('freeMcqIndex').doc('current');

  List<Map<String, String>> _exams = [];
  List<Map<String, dynamic>> _sets = [];
  FreeMcqSettings _settings = const FreeMcqSettings();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List<Map<String, String>> _parseExams(dynamic raw) {
    final out = <Map<String, String>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final id = (e['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          out.add({
            'id': id,
            'name': (e['name'] ?? '').toString(),
            'emoji': (e['emoji'] ?? '').toString(),
          });
        }
      }
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _ref.get().timeout(const Duration(seconds: 15));
      final data = snap.data() ?? <String, dynamic>{};
      final sets = <Map<String, dynamic>>[];
      final rawSets = data['sets'];
      if (rawSets is List) {
        for (final s in rawSets) {
          if (s is Map) sets.add(Map<String, dynamic>.from(s));
        }
      }
      var settings = const FreeMcqSettings();
      try {
        final sSnap = await _db.collection('appConfig').doc('freeMcq').get().timeout(const Duration(seconds: 10));
        settings = FreeMcqSettings.fromMap(sSnap.data());
      } catch (_) {
        // defaults are shown
      }
      if (!mounted) return;
      setState(() {
        _exams = _parseExams(data['exams']);
        _sets = sets;
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load: $e';
        _loading = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _setCount(String examId) => _sets.where((s) => (s['examId'] ?? '').toString() == examId).length;

  /// Letters+digits only, so it is safe inside a set id (examId_subjectId_yyyy-MM).
  String _newId(String name) {
    var base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.length > 24) base = base.substring(0, 24);
    if (base.isEmpty) base = 'exam${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    var id = base;
    var n = 2;
    final taken = _exams.map((e) => e['id']).toSet();
    while (taken.contains(id)) {
      id = '$base$n';
      n++;
    }
    return id;
  }

  /// Reads the CURRENT exams list from Firestore, lets [change] edit it and
  /// writes it back in one transaction (so a stale screen can never overwrite
  /// something newer). Optionally also drops the sets of [dropSetsOfExam]
  /// from the index.
  Future<bool> _mutate(List<Map<String, String>> Function(List<Map<String, String>>) change, {String? dropSetsOfExam}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_ref);
        final data = snap.data() ?? <String, dynamic>{};
        final next = change(_parseExams(data['exams']));
        final update = <String, dynamic>{'exams': next};
        if (dropSetsOfExam != null && data['sets'] is List) {
          update['sets'] = (data['sets'] as List)
              .where((s) => !(s is Map && (s['examId'] ?? '').toString() == dropSetsOfExam))
              .toList();
        }
        tx.set(_ref, update, SetOptions(merge: true));
      });
      // Refresh this phone's own cached copy so the student screen matches.
      try {
        await FreeMcqService().loadIndex(force: true);
      } catch (_) {}
      return true;
    } catch (e) {
      _snack('Could not save: $e');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final r = await _showExamDialog(title: 'Add exam folder', emoji: '📘', name: '');
    if (r == null) return;
    final id = _newId(r.name);
    final ok = await _mutate((cur) {
      // Make sure the id is still free in the freshest list.
      var useId = id;
      var n = 2;
      while (cur.any((e) => e['id'] == useId)) {
        useId = '$id$n';
        n++;
      }
      return [
        ...cur,
        {'id': useId, 'name': r.name, 'emoji': r.emoji},
      ];
    });
    if (ok) {
      _snack('Added "${r.name}". Its MCQ sets appear after the next weekly run (Monday).');
      await _load();
    }
  }

  Future<void> _edit(Map<String, String> exam) async {
    final r = await _showExamDialog(title: 'Edit exam folder', emoji: exam['emoji'] ?? '', name: exam['name'] ?? '');
    if (r == null) return;
    final ok = await _mutate((cur) => [
          for (final e in cur)
            if (e['id'] == exam['id']) {'id': e['id']!, 'name': r.name, 'emoji': r.emoji} else e,
        ]);
    if (ok) {
      _snack('Saved');
      await _load();
    }
  }

  Future<void> _move(int index, int delta) async {
    final id = _exams[index]['id'];
    final ok = await _mutate((cur) {
      final i = cur.indexWhere((e) => e['id'] == id);
      final j = i + delta;
      if (i < 0 || j < 0 || j >= cur.length) return cur;
      final copy = [...cur];
      final item = copy.removeAt(i);
      copy.insert(j, item);
      return copy;
    });
    if (ok) await _load();
  }

  Future<void> _remove(Map<String, String> exam) async {
    final id = exam['id']!;
    if (id == kEnglishFolderId) {
      _snack('The English folder is built in and cannot be removed.');
      return;
    }
    final count = _setCount(id);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Remove "${exam['name']}"?', style: TextStyle(color: AppC.text)),
        content: Text(
          'This folder and its $count MCQ set(s) will be deleted for all students. This cannot be undone.',
          style: TextStyle(color: AppC.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _removeNow(exam);
  }

  /// Removes the exam folder and its sets (no question asked). Used by "Remove" and by "Move to Mock Tests".
  Future<bool> _removeNow(Map<String, String> exam) async {
    final id = exam['id']!;
    // 1) Take the folder out of the index first, so students stop seeing it.
    final ok = await _mutate((cur) => cur.where((e) => e['id'] != id).toList(), dropSetsOfExam: id);
    if (!ok) return false;

    // 2) Then delete its set documents (the weekly script also cleans up any leftovers).
    try {
      final snap = await _db.collection('freeMcqSets').where('examId', isEqualTo: id).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      _snack('Folder removed, but some old sets could not be deleted now (the weekly run will clean them): $e');
    }
    _snack('Removed "${exam['name']}"');
    await _load();
    return true;
  }

  /// Settings (timer / marks / negative) of every Free MCQ test.
  Future<void> _editSettings() async {
    final r = await showFreeMcqSettingsDialog(context, _settings);
    if (r == null) return;
    try {
      await FreeMcqService().saveSettings(r);
      if (!mounted) return;
      setState(() => _settings = r);
      _snack('Saved');
    } catch (e) {
      _snack('Could not save: $e');
    }
  }

  /// Copy / move one exam folder of the Free MCQs into the Mock Tests section (and / or paid batches).
  Future<void> _copyToMocks(Map<String, String> exam) async {
    if (_busy) return;
    final examId = exam['id']!;
    final examName = exam['name'] ?? '';
    final fs = FirestoreService();
    FreeMcqIndex? index;
    var batches = <BatchModel>[];
    var mockFolders = <MockTestFolderModel>[];
    setState(() => _busy = true);
    try {
      index = await FreeMcqService().loadIndex(force: true);
      batches = await fs.streamBatches().first.timeout(const Duration(seconds: 12));
      mockFolders = await fs.streamMockFolders().first.timeout(const Duration(seconds: 12));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _snack('Could not load the data \u2014 check your internet and try again.');
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;
    if (index == null) {
      _snack('Free MCQs are not ready yet.');
      return;
    }
    final examSets = index.setsForExam(examId);
    if (examSets.isEmpty) {
      _snack('"$examName" has no sets yet. Copy it after its first weekly sets are made.');
      return;
    }
    final subjectIds = examSets.map((s) => s.subjectId).toSet();
    final subjects = examId == kEnglishFolderId ? <FreeMcqChoice>[] : index.subjects.where((s) => subjectIds.contains(s.id)).toList();

    final wanted = examName.trim().toLowerCase();
    final sameNameIn = <String>{};
    for (final f in mockFolders) {
      if (f.examName.trim().toLowerCase() != wanted) continue;
      if (f.isFree) {
        sameNameIn.add(kCopyFreeDest);
      } else {
        sameNameIn.addAll(f.batchIds);
      }
    }

    final choice = await showFreeToMockDialog(
      context,
      examName: examName,
      setCount: examSets.length,
      subjects: subjects,
      batches: batches,
      canMove: examId != kEnglishFolderId,
      sameNameIn: sameNameIn,
      settings: index.settings,
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    _snack('${choice.move ? 'Moving' : 'Copying'} "$examName" to Mock Tests ... please wait');
    try {
      final res = await fs.copyFreeMcqExamToMocks(
        exam: FreeMcqChoice(examId, examName, exam['emoji'] ?? ''),
        index: index,
        destinations: choice.destinations,
        settings: choice.settings,
        onlySubjectId: choice.subjectId,
      );
      if (mounted) setState(() => _busy = false);
      final skipNote = res.skipped > 0 ? ' (${res.skipped} already there, skipped)' : '';
      if (choice.move) {
        // Only now remove it from Free MCQs: everything was copied without an error.
        final removed = await _removeNow(exam);
        _snack(removed
            ? 'Moved "$examName": ${res.added} tests added to Mock Tests$skipNote.'
            : 'Copied ${res.added} tests, but could not remove the folder from Free MCQs. Remove it by hand.');
      } else {
        _snack('Copied "$examName": ${res.added} tests added$skipNote.');
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack('Copy failed: $e');
    }
  }

  Future<({String emoji, String name})?> _showExamDialog({required String title, required String emoji, required String name}) {
    return showDialog<({String emoji, String name})>(
      context: context,
      builder: (_) => _ExamDialog(title: title, emoji: emoji, name: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppC.red)),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'Exam folders of the Free MCQs section. Students see these folders; each one gets 3 subjects (Static GK, General Science, General Studies) with a new 25-question set every WEEK. The "English" folder is built in: it gets only 25 Banking PO / Clerk English MCQs every week (easy + moderate + hard, no GK / Science / GS) and cannot be removed. Sets older than 2 months are deleted automatically (database and students\u2019 phones).',
            style: TextStyle(color: AppC.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          DepthCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.timer_outlined, color: AppC.gold),
              title: Text('Test settings (like Mock Tests)', style: TextStyle(color: AppC.text, fontSize: 14)),
              subtitle: Text(
                '${_settings.durationMinutes > 0 ? '${_settings.durationMinutes} min' : 'No timer'} \u2022 +${_fmtNum(_settings.marksPerQuestion)} per correct \u2022 \u2212${_fmtNum(_settings.negativeMarks)} per wrong',
                style: TextStyle(color: AppC.muted, fontSize: 11.5),
              ),
              trailing: IconButton(
                tooltip: 'Edit test settings',
                icon: Icon(Icons.edit, size: 20, color: AppC.gold),
                onPressed: _busy ? null : _editSettings,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppC.gold, foregroundColor: Colors.black),
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Add exam folder'),
          ),
          const SizedBox(height: 12),
          if (_exams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No exam folders in the database yet. The weekly run will create the default ones (SSC, UPSSSC, Railway), or add your own above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppC.muted),
              ),
            ),
          for (var i = 0; i < _exams.length; i++)
            DepthCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title gets the full width; the buttons sit in their own row below it.
                    Row(
                      children: [
                        Text(_exams[i]['emoji']!.isEmpty ? '📘' : _exams[i]['emoji']!, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_exams[i]['name']!, style: TextStyle(color: AppC.text, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('${_setCount(_exams[i]['id']!)} sets', style: TextStyle(color: AppC.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          icon: Icon(Icons.arrow_upward, size: 20, color: AppC.muted),
                          onPressed: (_busy || i == 0) ? null : () => _move(i, -1),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          icon: Icon(Icons.arrow_downward, size: 20, color: AppC.muted),
                          onPressed: (_busy || i == _exams.length - 1) ? null : () => _move(i, 1),
                        ),
                        IconButton(
                          tooltip: 'Copy / Move to Mock Tests',
                          icon: Icon(Icons.drive_file_move_outline, size: 22, color: AppC.sky),
                          onPressed: _busy ? null : () => _copyToMocks(_exams[i]),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          icon: Icon(Icons.edit, size: 20, color: AppC.gold),
                          onPressed: _busy ? null : () => _edit(_exams[i]),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: Icon(Icons.delete_outline, size: 22, color: AppC.red),
                          onPressed: (_busy || _exams[i]['id'] == kEnglishFolderId) ? null : () => _remove(_exams[i]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _ExamDialog extends StatefulWidget {
  final String title;
  final String emoji;
  final String name;
  const _ExamDialog({required this.title, required this.emoji, required this.name});

  @override
  State<_ExamDialog> createState() => _ExamDialogState();
}

class _ExamDialogState extends State<_ExamDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late final TextEditingController _emoji = TextEditingController(text: widget.emoji);

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    var emoji = _emoji.text.trim();
    if (emoji.isEmpty) emoji = '📘';
    // Keep just the first emoji/character the admin typed.
    emoji = emoji.characters.take(2).toString();
    Navigator.pop(context, (emoji: emoji, name: name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppC.card,
      title: Text(widget.title, style: TextStyle(color: AppC.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emoji,
            style: TextStyle(color: AppC.text, fontSize: 22),
            decoration: InputDecoration(labelText: 'Emoji (optional)', labelStyle: TextStyle(color: AppC.muted)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            style: TextStyle(color: AppC.text),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Exam name',
              hintText: 'e.g. Bank PO',
              labelStyle: TextStyle(color: AppC.muted),
              hintStyle: TextStyle(color: AppC.muted),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppC.gold, foregroundColor: Colors.black),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
