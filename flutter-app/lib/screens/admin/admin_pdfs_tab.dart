import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/image_upload_service.dart';
import '../../models/models.dart';
import '../../widgets/net_image.dart';

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

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF081136),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
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
      await _fs.addFolder(PdfFolderModel(id: '', name: _newFolderName.text.trim(), type: _type, batchId: _type == 'batch' ? _selectedBatchId : null));
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
        batchId: _type == 'batch' ? _selectedBatchId : null,
        folderId: _selectedFolderId,
      ));
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
      await _fs.deletePdf(p.id, batchId: p.batchId);
      if (mounted) setState(() => _statusMsg = 'PDF deleted.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Delete failed: $e');
    }
  }

  Future<void> _deleteFolderConfirm(String folderId, String folderName) async {
    final ok = await _confirm('Delete folder?', 'Delete the folder "$folderName"? All PDFs inside it will be deleted too. This cannot be undone.');
    if (!ok) return;
    try {
      await _fs.deletePdfFolder(folderId, batchId: _type == 'batch' ? _selectedBatchId : null);
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('1. Choose section', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                hint: const Text('Choose batch', style: TextStyle(color: Colors.grey)),
                value: _validId(_selectedBatchId, batches.map((b) => b.id)),
                dropdownColor: const Color(0xFF081136),
                isExpanded: true,
                items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.title, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() {
                  _selectedBatchId = v;
                  _selectedFolderId = null;
                }),
              );
            },
          ),
        ],
        const Divider(color: Colors.grey),
        const Text('2. Choose a folder or create new', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_type == 'free' || _selectedBatchId != null)
          StreamBuilder<List<PdfFolderModel>>(
            stream: _fs.streamFolders(type: _type, batchId: _type == 'batch' ? _selectedBatchId : null),
            builder: (context, snap) {
              final folders = snap.data ?? <PdfFolderModel>[];
              final selected = folders.where((f) => f.id == _selectedFolderId).toList();
              return Row(children: [
                Expanded(
                  child: DropdownButton<String>(
                    hint: const Text('Choose folder', style: TextStyle(color: Colors.grey)),
                    value: _validId(_selectedFolderId, folders.map((f) => f.id)),
                    dropdownColor: const Color(0xFF081136),
                    isExpanded: true,
                    items: folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _selectedFolderId = v),
                  ),
                ),
                if (_selectedFolderId != null && selected.isNotEmpty)
                  IconButton(tooltip: 'Delete this folder', icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteFolderConfirm(selected.first.id, selected.first.name)),
              ]);
            },
          ),
        Row(children: [
          Expanded(child: TextField(controller: _newFolderName, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'New folder name', hintStyle: TextStyle(color: Colors.grey)))),
          IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFFFFF29)), onPressed: _createFolder),
        ]),
        const Divider(color: Colors.grey),
        const Text('3. Add PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: _pickIcon,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFF050B24), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade800)),
              child: _iconFile != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_iconFile!, fit: BoxFit.cover)) : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _pdfTitle, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'PDF title', hintStyle: TextStyle(color: Colors.grey)))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _driveLink, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Google Drive link (or upload from phone below)', labelStyle: TextStyle(color: Colors.grey))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _uploadPdfFromPhone,
          icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
          label: Text(_uploading ? 'Uploading...' : 'Upload PDF directly from phone'),
        ),
        if (_statusMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_statusMsg!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _adding ? null : _addPdf,
          child: _adding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add PDF'),
        ),
        if (_selectedFolderId != null) ...[
          const Divider(color: Colors.grey, height: 30),
          const Text('Existing PDFs in this folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<PdfModel>>(
            stream: _fs.streamPdfsInFolder(_selectedFolderId!),
            builder: (context, snap) {
              if (snap.hasError) return Text('Could not load: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12));
              if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator()));
              final pdfs = snap.data!;
              if (pdfs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('There is no PDF in this folder yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
              return Column(
                children: pdfs
                    .map((p) => ListTile(
                          dense: true,
                          leading: NetImage(url: p.iconUrl, width: 34, height: 34, fallbackIcon: '📄', radius: 6),
                          title: Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deletePdfConfirm(p)),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}
