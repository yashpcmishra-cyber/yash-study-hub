import 'package:flutter/material.dart';

/// Small dialog used by the Admin Panel (Mock Tests / PDFs / Videos tabs) to
/// rename a folder. Returns the new trimmed name, or null if the admin
/// cancelled or did not change anything.
Future<String?> showRenameFolderDialog(BuildContext context, {required String currentName, String title = 'Rename folder'}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameFolderDialog(currentName: currentName, title: title),
  );
}

class _RenameFolderDialog extends StatefulWidget {
  final String currentName;
  final String title;
  const _RenameFolderDialog({required this.currentName, required this.title});

  @override
  State<_RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<_RenameFolderDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final name = _c.text.trim();
    // Empty or unchanged name = nothing to save.
    if (name.isEmpty || name == widget.currentName.trim()) {
      Navigator.pop(context, null);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF081136),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: _c,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(hintText: 'New folder name', hintStyle: TextStyle(color: Colors.grey)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFFF29), foregroundColor: Colors.black),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
