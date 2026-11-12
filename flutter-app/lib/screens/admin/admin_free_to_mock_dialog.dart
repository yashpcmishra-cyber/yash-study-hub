import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../models/models.dart';
import '../../services/free_mcq_service.dart';

/// Checks the three test-setting fields; returns the settings, or sets [error] and returns null.
FreeMcqSettings? _parseSettings(String minutesText, String marksText, String negText, void Function(String) error) {
  final minutes = int.tryParse(minutesText.trim());
  final marks = double.tryParse(marksText.trim().replaceAll(',', '.'));
  final neg = double.tryParse(negText.trim().replaceAll(',', '.'));
  if (minutes == null || minutes < 0 || minutes > 300) {
    error('Time must be 0 to 300 minutes (0 = no timer).');
    return null;
  }
  if (marks == null || marks <= 0 || marks > 100) {
    error('Marks per question must be more than 0 (for example 1 or 2).');
    return null;
  }
  if (neg == null || neg < 0 || neg > marks) {
    error('Negative marks must be 0 or more, and not more than the marks of a correct answer.');
    return null;
  }
  return FreeMcqSettings(durationMinutes: minutes, marksPerQuestion: marks, negativeMarks: neg);
}

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Three text fields (time, marks, negative marks) shared by the settings dialog and the copy dialog.
class _SettingsFields extends StatelessWidget {
  final TextEditingController minutes;
  final TextEditingController marks;
  final TextEditingController neg;
  const _SettingsFields({required this.minutes, required this.marks, required this.neg});

  Widget _field(TextEditingController c, String label, {bool decimal = false}) {
    return Expanded(
      child: TextField(
        controller: c,
        style: TextStyle(color: AppC.text),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppC.muted, fontSize: 12),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _field(minutes, 'Time (min)'),
        const SizedBox(width: 8),
        _field(marks, 'Marks / Q', decimal: true),
        const SizedBox(width: 8),
        _field(neg, 'Negative', decimal: true),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Test settings of the Free MCQs (timer / marks / negative marking)
// ---------------------------------------------------------------------------

Future<FreeMcqSettings?> showFreeMcqSettingsDialog(BuildContext context, FreeMcqSettings current) {
  return showDialog<FreeMcqSettings>(context: context, builder: (_) => _SettingsDialog(current: current));
}

class _SettingsDialog extends StatefulWidget {
  final FreeMcqSettings current;
  const _SettingsDialog({required this.current});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final _minutes = TextEditingController(text: widget.current.durationMinutes.toString());
  late final _marks = TextEditingController(text: _fmt(widget.current.marksPerQuestion));
  late final _neg = TextEditingController(text: _fmt(widget.current.negativeMarks));
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    _marks.dispose();
    _neg.dispose();
    super.dispose();
  }

  void _save() {
    final s = _parseSettings(_minutes.text, _marks.text, _neg.text, (e) => setState(() => _error = e));
    if (s != null) Navigator.pop(context, s);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppC.card,
      title: Text('Free MCQs test settings', style: TextStyle(color: AppC.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Every Free MCQ test (each weekly set) opens like a Mock Test with this timer and marking. Students get the new values within about 12 hours.',
              style: TextStyle(color: AppC.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _SettingsFields(minutes: _minutes, marks: _marks, neg: _neg),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AppC.red, fontSize: 12)),
            ],
          ],
        ),
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

// ---------------------------------------------------------------------------
// Copy / Move a Free MCQs exam folder to Mock Tests
// ---------------------------------------------------------------------------

/// What the admin picked in [showFreeToMockDialog].
class FreeToMockChoice {
  /// kCopyFreeDest (= Mock Tests section) and / or paid batch ids.
  final List<String> destinations;

  /// Move = remove the folder from Free MCQs after copying. Copy = keep it there too.
  final bool move;

  /// Copy only this subject (null = every subject). Always null for Move.
  final String? subjectId;

  /// Timer / marks of the new mock tests.
  final FreeMcqSettings settings;
  const FreeToMockChoice(this.destinations, this.move, this.subjectId, this.settings);
}

/// [subjects] = subject folders of this exam that have at least one set (empty for the English folder).
/// [canMove] = false for the built-in English folder (it can never be removed from Free MCQs).
/// [sameNameIn] = destination ids where a mock folder with this name already exists
/// (the new tests are then added to it instead of making a second folder).
Future<FreeToMockChoice?> showFreeToMockDialog(
  BuildContext context, {
  required String examName,
  required int setCount,
  required List<FreeMcqChoice> subjects,
  required List<BatchModel> batches,
  required bool canMove,
  required Set<String> sameNameIn,
  required FreeMcqSettings settings,
}) {
  return showDialog<FreeToMockChoice>(
    context: context,
    builder: (_) => _FreeToMockDialog(
      examName: examName,
      setCount: setCount,
      subjects: subjects,
      batches: batches,
      canMove: canMove,
      sameNameIn: sameNameIn,
      settings: settings,
    ),
  );
}

class _FreeToMockDialog extends StatefulWidget {
  final String examName;
  final int setCount;
  final List<FreeMcqChoice> subjects;
  final List<BatchModel> batches;
  final bool canMove;
  final Set<String> sameNameIn;
  final FreeMcqSettings settings;
  const _FreeToMockDialog({
    required this.examName,
    required this.setCount,
    required this.subjects,
    required this.batches,
    required this.canMove,
    required this.sameNameIn,
    required this.settings,
  });

  @override
  State<_FreeToMockDialog> createState() => _FreeToMockDialogState();
}

class _FreeToMockDialogState extends State<_FreeToMockDialog> {
  final Set<String> _picked = <String>{kCopyFreeDest};
  bool _move = false;
  String? _subjectId; // null = every subject
  late final _minutes = TextEditingController(text: widget.settings.durationMinutes.toString());
  late final _marks = TextEditingController(text: _fmt(widget.settings.marksPerQuestion));
  late final _neg = TextEditingController(text: _fmt(widget.settings.negativeMarks));
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    _marks.dispose();
    _neg.dispose();
    super.dispose();
  }

  Widget _row(String id, String label) {
    final exists = widget.sameNameIn.contains(id);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _picked.contains(id),
      onChanged: (v) => setState(() {
        if (v == true) {
          _picked.add(id);
        } else {
          _picked.remove(id);
        }
      }),
      title: Text(label, style: TextStyle(color: AppC.text, fontSize: 13.5)),
      subtitle: exists
          ? Text('"${widget.examName}" folder already there — new tests are added to it', style: TextStyle(color: AppC.muted, fontSize: 11))
          : null,
    );
  }

  void _submit() {
    final s = _parseSettings(_minutes.text, _marks.text, _neg.text, (e) => setState(() => _error = e));
    if (s == null) return;
    Navigator.pop(context, FreeToMockChoice(_picked.toList(), _move, _move ? null : _subjectId, s));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppC.card,
      title: Text('Copy / Move to Mock Tests', style: TextStyle(color: AppC.text)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${widget.examName}"  •  ${widget.setCount} sets', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                'Every weekly set becomes one mock test (subject = subject folder). The copy is separate from the Free MCQs.',
                style: TextStyle(color: AppC.muted, fontSize: 11.5),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Copy'),
                    selected: !_move,
                    onSelected: (_) => setState(() => _move = false),
                  ),
                  ChoiceChip(
                    label: const Text('Move'),
                    selected: _move,
                    onSelected: widget.canMove ? (_) => setState(() => _move = true) : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _move
                    ? 'Move: after copying, the folder and its sets are REMOVED from Free MCQs (students no longer see it there, no new weekly sets are made). Cannot be undone.'
                    : widget.canMove
                        ? 'Copy: the folder also stays in Free MCQs.'
                        : 'Copy: the folder also stays in Free MCQs. (The built-in English folder cannot be moved.)',
                style: TextStyle(color: _move ? AppC.red : AppC.muted, fontSize: 11.5),
              ),
              if (!_move && widget.subjects.length > 1) ...[
                const SizedBox(height: 10),
                Text('What to copy', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
                DropdownButton<String?>(
                  value: _subjectId,
                  isExpanded: true,
                  dropdownColor: AppC.card,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('Whole folder (all subjects)', style: TextStyle(color: AppC.text, fontSize: 13))),
                    ...widget.subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text('Only subject: ${s.name}', style: TextStyle(color: AppC.text, fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
              ],
              const SizedBox(height: 10),
              Text('Copy to (tick one or more)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
              _row(kCopyFreeDest, 'Mock Tests (free)'),
              ...widget.batches.map((b) => _row(b.id, b.title)),
              const SizedBox(height: 10),
              Text('Test settings of the new mock tests', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 4),
              _SettingsFields(minutes: _minutes, marks: _marks, neg: _neg),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppC.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _picked.isEmpty ? null : _submit,
          child: Text(_move ? 'Move' : 'Copy'),
        ),
      ],
    );
  }
}
