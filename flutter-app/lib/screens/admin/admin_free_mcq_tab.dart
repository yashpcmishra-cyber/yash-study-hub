import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../services/free_mcq_service.dart';
import '../../widgets/depth_card.dart';

/// Admin Panel tab: add / edit / remove / reorder the EXAM folders shown in
/// the student-side "Free MCQs" section (SSC, UPSSSC, Railway ...).
///
/// Data lives in ONE document: freeMcqIndex/current  ->  field `exams`
/// (list of {id, name, emoji}). The monthly GitHub script reads this list
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
      if (!mounted) return;
      setState(() {
        _exams = _parseExams(data['exams']);
        _sets = sets;
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
      _snack('Added "${r.name}". Its MCQ sets appear after the next monthly run.');
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

    // 1) Take the folder out of the index first, so students stop seeing it.
    final ok = await _mutate((cur) => cur.where((e) => e['id'] != id).toList(), dropSetsOfExam: id);
    if (!ok) return;

    // 2) Then delete its set documents (the monthly script also cleans up any leftovers).
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
      _snack('Folder removed, but some old sets could not be deleted now (the monthly run will clean them): $e');
    }
    _snack('Removed "${exam['name']}"');
    await _load();
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
            'Exam folders of the Free MCQs section. Students see these folders; each one gets 3 subjects (Static GK, General Science, General Studies) with a new 25-question set every month.',
            style: TextStyle(color: AppC.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
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
                'No exam folders in the database yet. The monthly run will create the default ones (SSC, UPSSSC, Railway), or add your own above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppC.muted),
              ),
            ),
          for (var i = 0; i < _exams.length; i++)
            DepthCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Text(_exams[i]['emoji']!.isEmpty ? '📘' : _exams[i]['emoji']!, style: const TextStyle(fontSize: 22)),
                title: Text(_exams[i]['name']!, style: TextStyle(color: AppC.text)),
                subtitle: Text('${_setCount(_exams[i]['id']!)} sets', style: TextStyle(color: AppC.muted, fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
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
                      tooltip: 'Edit',
                      icon: Icon(Icons.edit, size: 20, color: AppC.gold),
                      onPressed: _busy ? null : () => _edit(_exams[i]),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: Icon(Icons.delete_outline, size: 22, color: AppC.red),
                      onPressed: _busy ? null : () => _remove(_exams[i]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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
