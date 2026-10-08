import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';

const _navy = Color(0xFF081136);
const _gold = Color(0xFFFFFF29);

/// Subject text box (optional) + tap-to-fill chips of the subjects that are
/// already used inside [folderId]. Leave it empty and the test shows directly
/// in the exam folder (exactly like before).
class MockSubjectField extends StatefulWidget {
  final TextEditingController controller;
  final String? folderId;
  final ValueChanged<String>? onChanged;
  const MockSubjectField({super.key, required this.controller, required this.folderId, this.onChanged});

  @override
  State<MockSubjectField> createState() => _MockSubjectFieldState();
}

class _MockSubjectFieldState extends State<MockSubjectField> {
  final _fs = FirestoreService();
  Stream<List<MockTestModel>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.folderId == null ? null : _fs.streamMockTests(widget.folderId!);
  }

  @override
  void didUpdateWidget(covariant MockSubjectField old) {
    super.didUpdateWidget(old);
    if (old.folderId != widget.folderId) {
      _stream = widget.folderId == null ? null : _fs.streamMockTests(widget.folderId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Subject folder (optional)',
            labelStyle: TextStyle(color: Colors.grey),
            hintText: 'e.g. Maths, Reasoning, English',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Students will see Exam folder > Subject folder > Tests. Leave empty to show the test directly inside the exam folder.',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        if (_stream != null)
          StreamBuilder<List<MockTestModel>>(
            stream: _stream,
            builder: (context, snap) {
              final groups = groupMockTestsBySubject(snap.data ?? <MockTestModel>[]).groups;
              if (groups.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final cur = mockSubjectKey(value.text);
                    return Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: groups.map((g) {
                        final on = mockSubjectKey(g.name) == cur;
                        return ChoiceChip(
                          label: Text(g.name, style: TextStyle(color: on ? _navy : Colors.white, fontSize: 12)),
                          selected: on,
                          selectedColor: _gold,
                          backgroundColor: const Color(0xFF101D57),
                          onSelected: (_) {
                            widget.controller.text = g.name;
                            widget.onChanged?.call(g.name);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Opens the "Move test" dialog. Returns true if the test was moved.
Future<bool> showMoveMockTestDialog(BuildContext context, MockTestModel test) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => _MoveMockTestDialog(test: test));
  return ok == true;
}

class _MoveMockTestDialog extends StatefulWidget {
  final MockTestModel test;
  const _MoveMockTestDialog({required this.test});

  @override
  State<_MoveMockTestDialog> createState() => _MoveMockTestDialogState();
}

class _MoveMockTestDialogState extends State<_MoveMockTestDialog> {
  final _fs = FirestoreService();
  late final Stream<List<MockTestFolderModel>> _foldersStream = _fs.streamMockFolders();
  late final Stream<List<BatchModel>> _batchesStream = _fs.streamBatches();
  late String _folderId = widget.test.folderId;
  late final TextEditingController _subject = TextEditingController(text: widget.test.subject);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  String _label(MockTestFolderModel f, Map<String, String> batchNames) {
    if (f.batchIds.isEmpty) return '${f.examName}  (FREE)';
    final names = f.batchIds.map((id) => batchNames[id] ?? 'deleted batch').join(', ');
    return '${f.examName}  (Batch: $names)';
  }

  Future<void> _move() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _fs.moveMockTest(widget.test.id, _folderId, _subject.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not move: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _navy,
      title: const Text('Move mock test', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: StreamBuilder<List<MockTestFolderModel>>(
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.test.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('Exam folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: valid,
                        hint: const Text('Choose exam folder', style: TextStyle(color: Colors.grey)),
                        dropdownColor: _navy,
                        items: folders
                            .map((f) => DropdownMenuItem(
                                  value: f.id,
                                  child: Text(_label(f, names), style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _folderId = v);
                        },
                      ),
                      if (_folderId != widget.test.folderId && cur.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            cur.first.batchIds.isEmpty
                                ? 'After moving, this test will be FREE for all students.'
                                : 'After moving, only students of the batch(es) shown above can open this test.',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 6),
                      MockSubjectField(controller: _subject, folderId: _folderId.isEmpty ? null : _folderId),
                      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _move,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Move'),
        ),
      ],
    );
  }
}
