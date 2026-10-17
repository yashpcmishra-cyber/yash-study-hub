import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/image_upload_service.dart';
import '../../models/models.dart';
import '../../widgets/net_image.dart';
import 'admin_rename_folder_dialog.dart';
import 'admin_reorder_list.dart';
import '../../app_colors.dart';

class AdminPdfsTab extends StatefulWidget {
  const AdminPdfsTab({super.key});
  @override
  State<AdminPdfsTab> createState() => _AdminPdfsTabState();
}

// AutomaticKeepAliveClientMixin: the tab keeps what you typed / selected
// when you switch to another tab and come back.
class _AdminPdfsTabState extends State<AdminPdfsTab> with AutomaticKeepAliveClientMixin {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _imageUpload = ImageUploadService();
  late final Stream<List<BatchModel>> _batchesStream = _fs.streamBatches();
  String _type = 'free'; // 'free' | 'batch'
  String? _selectedBatchId;
  String? _selectedFolderId;
  // The folders the dropdown is showing right now (kept up to date by the
  // stream below) - used to know which batches the chosen folder is in.
  List<PdfFolderModel> _shownFolders = <PdfFolderModel>[];
  final _newFolderName = TextEditingController();
  final _pdfTitle = TextEditingController();
  final _driveLink = TextEditingController();
  File? _iconFile;
  bool _uploading = false;
  bool _adding = false;
  String? _statusMsg;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _newFolderName.dispose();
    _pdfTitle.dispose();
    _driveLink.dispose();
    super.dispose();
  }

  // A dropdown crashes (in debug) if its value is not in its list, so
  // anything that is no longer in the list is treated as "nothing chosen".
  String? _validId(String? id, Iterable<String> ids) => (id != null && ids.contains(id)) ? id : null;

  PdfFolderModel? get _selectedFolder {
    for (final f in _shownFolders) {
      if (f.id == _selectedFolderId) return f;
    }
    return null;
  }

  // Every paid batch the chosen folder is in ([] for a free folder).
  List<String> get _selectedFolderBatchIds => _type == 'batch' ? (_selectedFolder?.batchIds ?? <String>[]) : <String>[];

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
    if (_type == 'batch' && _selectedBatchId == null) {
      setState(() => _statusMsg = 'Choose a batch first.');
      return;
    }
    try {
      await _fs.addFolder(PdfFolderModel(
        id: '',
        name: _newFolderName.text.trim(),
        type: _type,
        batchId: _type == 'batch' ? _selectedBatchId : null,
        batchIds: _type == 'batch' ? <String>[_selectedBatchId!] : <String>[],
      ));
      _newFolderName.clear();
      if (mounted) setState(() => _statusMsg = 'Folder created.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Could not create the folder: $e');
    }
  }

  Future<void> _pickIcon() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null && mounted) setState(() => _iconFile = File(img.path));
  }

  Future<void> _uploadPdfFromPhone() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _uploading = true;
      _statusMsg = null;
    });
    try {
      final url = await _storage.uploadFile(File(result.files.single.path!), 'pdfs/${_selectedFolderId ?? "misc"}');
      if (!mounted) return;
      setState(() {
        _driveLink.text = url;
        _uploading = false;
        _statusMsg = 'Uploaded \u2014 now tap "Add PDF".';
      });
    } on StorageNotReadyException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _statusMsg = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _statusMsg = 'Upload failed: $e';
      });
    }
  }

  Future<void> _addPdf() async {
    if (_adding) return;
    if (_selectedFolderId == null || _pdfTitle.text.trim().isEmpty || _driveLink.text.trim().isEmpty) {
      setState(() => _statusMsg = 'Choose a folder \u2014 title and link/upload are both required.');
      return;
    }
    setState(() {
      _adding = true;
      _statusMsg = null;
    });
    String? iconUrl;
    String? iconNote;
    if (_iconFile != null) {
      try {
        iconUrl = await _imageUpload.uploadImage(_iconFile!);
      } on ImageUploadNotConfiguredException catch (e) {
        iconNote = e.message; // icon is optional, PDF still gets added without it
      } catch (e) {
        iconNote = 'Icon upload failed ($e)';
      }
    }
    try {
      await _fs.addPdf(PdfModel(
        id: '',
        title: _pdfTitle.text.trim(),
        iconUrl: iconUrl,
        driveLink: _driveLink.text.trim(),
        batchId: _type == 'batch' ? (_selectedFolder?.batchId ?? _selectedBatchId) : null,
        folderId: _selectedFolderId,
      ), batchIds: _selectedFolderBatchIds);
      _pdfTitle.clear();
      _driveLink.clear();
      if (mounted) {
        setState(() {
          _iconFile = null;
          _statusMsg = iconNote == null ? 'PDF added.' : 'PDF added without an icon. $iconNote';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Could not add the PDF: $e');
    }
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _deletePdfConfirm(PdfModel p) async {
    final ok = await _confirm('Delete PDF?', 'Delete "${p.title}"?');
    if (!ok) return;
    try {
      await _fs.deletePdf(p.id, batchId: p.batchId, batchIds: _selectedFolderBatchIds);
      if (mounted) setState(() => _statusMsg = 'PDF deleted.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Delete failed: $e');
    }
  }

  Future<void> _renameFolder(String folderId, String currentName) async {
    final newName = await showRenameFolderDialog(context, currentName: currentName);
    if (newName == null) return;
    try {
      await _fs.renamePdfFolder(folderId, newName);
      if (mounted) setState(() => _statusMsg = 'Folder renamed.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Rename failed: $e');
    }
  }

  Future<void> _deleteFolderConfirm(String folderId, String folderName) async {
    final ok = await _confirm('Delete folder?', 'Delete the folder "$folderName"? All PDFs inside it will be deleted too. This cannot be undone.');
    if (!ok) return;
    try {
      await _fs.deletePdfFolder(folderId, batchId: _type == 'batch' ? _selectedBatchId : null, batchIds: _selectedFolderBatchIds);
      if (mounted) {
        setState(() {
          _selectedFolderId = null;
          _statusMsg = 'Folder deleted.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Delete failed: $e');
    }
  }

  // Paid batches for the chosen folder: tap a batch to add / remove it.
  // A folder can be in at most 3 batches and always stays in at least 1.
  Widget _batchPicker(PdfFolderModel f) {
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
              Text('Shown ONLY inside the paid batch(es) selected below', style: TextStyle(color: AppC.orange, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Tap a batch to add / remove it (max 3). At least 1 batch must stay.', style: TextStyle(color: AppC.muted, fontSize: 11)),
              const SizedBox(height: 4),
              if (batches.isEmpty)
                Text('No paid batch created yet', style: TextStyle(color: AppC.muted, fontSize: 12))
              else
                Wrap(
                  spacing: 6,
                  children: batches.map((b) {
                    final on = chosen.contains(b.id);
                    return FilterChip(
                      label: Text(b.title, style: TextStyle(color: on ? AppC.onGold : AppC.text, fontSize: 12)),
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

  Future<void> _toggleBatch(PdfFolderModel f, String batchId, bool on, Set<String> existing) async {
    // Batches that were deleted meanwhile are dropped from the list.
    final next = f.batchIds.where(existing.contains).toList();
    if (on) {
      if (next.contains(batchId)) return;
      if (next.length >= 3) {
        setState(() => _statusMsg = 'A folder can be in at most 3 batches. Remove one first.');
        return;
      }
      next.add(batchId);
    } else {
      next.remove(batchId);
      if (next.isEmpty) {
        setState(() => _statusMsg = 'A folder must stay in at least 1 batch. First add the new batch, then remove this one. (To remove the folder completely, use the delete icon.)');
        return;
      }
    }
    try {
      await _fs.setPdfFolderBatches(f.id, next, oldIds: f.batchIds);
      if (!mounted) return;
      // The folder just left the batch that is being viewed -> it is no
      // longer in this list, so nothing stays selected.
      final leftThisView = _type == 'batch' && _selectedBatchId != null && !next.contains(_selectedBatchId);
      setState(() {
        if (leftThisView) _selectedFolderId = null;
        _statusMsg = leftThisView ? 'Folder moved out of this batch. Pick the other batch above to see it.' : 'Batches updated.';
      });
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Could not update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('1. Choose section', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          ChoiceChip(label: const Text('Free PDFs'), selected: _type == 'free', onSelected: (_) => setState(() {
                _type = 'free';
                _selectedFolderId = null;
              })),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('Paid Batch PDFs'), selected: _type == 'batch', onSelected: (_) => setState(() {
                _type = 'batch';
                _selectedFolderId = null;
              })),
        ]),
        if (_type == 'batch') ...[
          const SizedBox(height: 12),
          StreamBuilder<List<BatchModel>>(
            stream: _batchesStream,
            builder: (context, snap) {
              final batches = snap.data ?? <BatchModel>[];
              return DropdownButton<String>(
                hint: Text('Choose batch', style: TextStyle(color: AppC.muted)),
                value: _validId(_selectedBatchId, batches.map((b) => b.id)),
                dropdownColor: AppC.card,
                isExpanded: true,
                items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.title, style: TextStyle(color: AppC.text)))).toList(),
                onChanged: (v) => setState(() {
                  _selectedBatchId = v;
                  _selectedFolderId = null;
                }),
              );
            },
          ),
        ],
        Divider(color: AppC.divider),
        Text('2. Choose a folder or create new', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_type == 'free' || _selectedBatchId != null)
          StreamBuilder<List<PdfFolderModel>>(
            stream: _fs.streamFolders(type: _type, batchId: _type == 'batch' ? _selectedBatchId : null),
            builder: (context, snap) {
              final folders = snap.data ?? <PdfFolderModel>[];
              _shownFolders = folders;
              final selected = folders.where((f) => f.id == _selectedFolderId).toList();
              final folderRow = Row(children: [
                Expanded(
                  child: DropdownButton<String>(
                    hint: Text('Choose folder', style: TextStyle(color: AppC.muted)),
                    value: _validId(_selectedFolderId, folders.map((f) => f.id)),
                    dropdownColor: AppC.card,
                    isExpanded: true,
                    items: folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: TextStyle(color: AppC.text)))).toList(),
                    onChanged: (v) => setState(() => _selectedFolderId = v),
                  ),
                ),
                if (_selectedFolderId != null && selected.isNotEmpty) ...[
                  IconButton(tooltip: 'Rename this folder', icon: Icon(Icons.edit, color: AppC.accent, size: 20), onPressed: () => _renameFolder(selected.first.id, selected.first.name)),
                  IconButton(tooltip: 'Delete this folder', icon: Icon(Icons.delete, color: AppC.red, size: 20), onPressed: () => _deleteFolderConfirm(selected.first.id, selected.first.name)),
                ],
              ]);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  folderRow,
                  if (_type == 'batch' && selected.isNotEmpty) _batchPicker(selected.first),
                  if (folders.length >= 2)
                    AdminFolderOrderSection<PdfFolderModel>(
                      items: folders,
                      idOf: (f) => f.id,
                      labelOf: (f) => f.name,
                      onSave: (list) => _fs.saveOrder('pdfFolders', list.map((f) => f.id).toList()),
                    ),
                ],
              );
            },
          ),
        Row(children: [
          Expanded(child: TextField(controller: _newFolderName, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'New folder name', hintStyle: TextStyle(color: AppC.muted)))),
          IconButton(icon: Icon(Icons.add_circle, color: AppC.accent), onPressed: _createFolder),
        ]),
        Divider(color: AppC.divider),
        Text('3. Add PDF', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: _pickIcon,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppC.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.line2)),
              child: _iconFile != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_iconFile!, fit: BoxFit.cover)) : Icon(Icons.image, color: AppC.muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _pdfTitle, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'PDF title', hintStyle: TextStyle(color: AppC.muted)))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _driveLink, style: TextStyle(color: AppC.text), decoration: InputDecoration(labelText: 'Google Drive link (or upload from phone below)', labelStyle: TextStyle(color: AppC.muted))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _uploadPdfFromPhone,
          icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
          label: Text(_uploading ? 'Uploading...' : 'Upload PDF directly from phone'),
        ),
        if (_statusMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_statusMsg!, style: TextStyle(color: AppC.orange, fontSize: 12))),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _adding ? null : _addPdf,
          child: _adding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add PDF'),
        ),
        if (_selectedFolderId != null) ...[
          Divider(color: AppC.divider, height: 30),
          Text('Existing PDFs in this folder', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<PdfModel>>(
            stream: _fs.streamPdfsInFolder(_selectedFolderId!),
            builder: (context, snap) {
              if (snap.hasError) return Text('Could not load: ${snap.error}', style: TextStyle(color: AppC.orange, fontSize: 12));
              if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator()));
              final pdfs = snap.data!;
              if (pdfs.isEmpty) return Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('There is no PDF in this folder yet', style: TextStyle(color: AppC.muted, fontSize: 12)));
              return AdminReorderList<PdfModel>(
                items: pdfs,
                idOf: (p) => p.id,
                onSave: (list) => _fs.saveOrder('pdfs', list.map((p) => p.id).toList()),
                contentBuilder: (context, p) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: NetImage(url: p.iconUrl, width: 34, height: 34, fallbackIcon: '📄', radius: 6),
                  title: Text(p.title, style: TextStyle(color: AppC.text, fontSize: 13)),
                  trailing: IconButton(padding: const EdgeInsets.all(6), constraints: const BoxConstraints(), icon: Icon(Icons.delete, color: AppC.red, size: 18), onPressed: () => _deletePdfConfirm(p)),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
