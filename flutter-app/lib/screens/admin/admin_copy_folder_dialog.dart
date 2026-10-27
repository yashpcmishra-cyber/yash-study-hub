import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../app_colors.dart';

/// What the admin picked in [showCopyFolderDialog].
class CopyFolderChoice {
  /// Paid batch ids and / or [kCopyFreeDest] (= the free section).
  final List<String> destinations;

  /// Mock tests only: copy just this subject folder (null = the whole exam folder).
  final String? subject;
  const CopyFolderChoice(this.destinations, this.subject);
}

/// Admin Panel "Copy folder" dialog (PDFs / Videos / Mock Tests tabs).
/// The admin ticks one or more places (the free section and / or paid
/// batches) and the whole folder is copied into each of them.
///
/// [alreadyIn] = ids of the places the folder is in right now (shown as
/// "already here" and cannot be ticked, so nothing is duplicated by accident).
/// [subjects] = (mock tests only) the subject folders inside the exam folder;
/// when given, the admin can copy just one subject instead of everything.
Future<CopyFolderChoice?> showCopyFolderDialog(
  BuildContext context, {
  required String folderName,
  required String freeLabel,
  required List<BatchModel> batches,
  Set<String> alreadyIn = const <String>{},
  List<String> subjects = const <String>[],
}) {
  return showDialog<CopyFolderChoice>(
    context: context,
    builder: (_) => _CopyFolderDialog(
      folderName: folderName,
      freeLabel: freeLabel,
      batches: batches,
      alreadyIn: alreadyIn,
      subjects: subjects,
    ),
  );
}

class _CopyFolderDialog extends StatefulWidget {
  final String folderName;
  final String freeLabel;
  final List<BatchModel> batches;
  final Set<String> alreadyIn;
  final List<String> subjects;
  const _CopyFolderDialog({
    required this.folderName,
    required this.freeLabel,
    required this.batches,
    required this.alreadyIn,
    required this.subjects,
  });

  @override
  State<_CopyFolderDialog> createState() => _CopyFolderDialogState();
}

class _CopyFolderDialogState extends State<_CopyFolderDialog> {
  final Set<String> _picked = <String>{};
  String? _subject; // null = whole exam folder

  Widget _row(String id, String label) {
    final here = widget.alreadyIn.contains(id);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: here ? false : _picked.contains(id),
      onChanged: here
          ? null
          : (v) => setState(() {
                if (v == true) {
                  _picked.add(id);
                } else {
                  _picked.remove(id);
                }
              }),
      title: Text(label, style: TextStyle(color: here ? AppC.muted : AppC.text, fontSize: 13.5)),
      subtitle: here ? Text('already here', style: TextStyle(color: AppC.muted, fontSize: 11)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppC.card,
      title: Text('Copy folder', style: TextStyle(color: AppC.text)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${widget.folderName}"', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                'The folder and everything inside it is copied. The copy is separate \u2014 changing or deleting it never touches the original.',
                style: TextStyle(color: AppC.muted, fontSize: 11.5),
              ),
              if (widget.subjects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('What to copy', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
                DropdownButton<String?>(
                  value: _subject,
                  isExpanded: true,
                  dropdownColor: AppC.card,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('Whole exam folder (all subjects)', style: TextStyle(color: AppC.text, fontSize: 13))),
                    ...widget.subjects.map((s) => DropdownMenuItem<String?>(value: s, child: Text('Only subject: $s', style: TextStyle(color: AppC.text, fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _subject = v),
                ),
              ],
              const SizedBox(height: 10),
              Text('Copy to (tick one or more)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
              _row(kCopyFreeDest, widget.freeLabel),
              if (widget.batches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('No paid batch available for this content', style: TextStyle(color: AppC.muted, fontSize: 12)),
                )
              else
                ...widget.batches.map((b) => _row(b.id, b.title)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, CopyFolderChoice(_picked.toList(), _subject)),
          child: Text(_picked.isEmpty ? 'Copy' : 'Copy to ${_picked.length}'),
        ),
      ],
    );
  }
}
