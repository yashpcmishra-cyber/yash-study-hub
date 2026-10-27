import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/image_upload_service.dart';
import '../../models/models.dart';
import '../../widgets/net_image.dart';
import 'admin_copy_folder_dialog.dart';
import 'admin_rename_folder_dialog.dart';
import 'admin_reorder_list.dart';
import '../../app_colors.dart';

class AdminVideosTab extends StatefulWidget {
  const AdminVideosTab({super.key});
  @override
  State<AdminVideosTab> createState() => _AdminVideosTabState();
}

// AutomaticKeepAliveClientMixin: the tab keeps what you typed / selected
// when you switch to another tab and come back.
class _AdminVideosTabState extends State<AdminVideosTab> with AutomaticKeepAliveClientMixin {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _imageUpload = ImageUploadService();
  late final Stream<List<BatchModel>> _batchesStream = _fs.streamBatches();
  String? _selectedBatchId; // null = free/public Video Classes section
  String? _selectedFolderId; // batch: required. free: optional (null = loose video)
  final _newFolderName = TextEditingController();
  final _title = TextEditingController();
  final _link = TextEditingController();
  File? _thumbFile;
  bool _uploading = false;
  bool _adding = false;
  String? _statusMsg;

  @override
  bool get wantKeepAlive => true;

  bool get _isFree => _selectedBatchId == null;

  @override
  void dispose() {
    _newFolderName.dispose();
    _title.dispose();
    _link.dispose();
    super.dispose();
  }

  // A dropdown crashes (in debug) if its value is not in its list, so
  // anything that is no longer in the list is treated as "nothing chosen".
  String? _validId(String? id, Iterable<String> ids) => (id != null && ids.contains(id)) ? id : null;

  Future<bool> _confirm(String title, String message, {String action = 'Delete'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text(title, style: TextStyle(color: AppC.text)),
        content: Text(message, style: TextStyle(color: AppC.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(dialogContext, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _createFolder() async {
    if (_newFolderName.text.trim().isEmpty) return;
    try {
      await _fs.addVideoFolder(VideoFolderModel(id: '', name: _newFolderName.text.trim(), batchId: _selectedBatchId ?? kFreeVideoBatchId));
      _newFolderName.clear();
      if (mounted) setState(() => _statusMsg = 'Folder created.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Could not create the folder: $e');
    }
  }

  Future<void> _pickThumb() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null && mounted) setState(() => _thumbFile = File(img.path));
  }

  Future<void> _uploadVideoFromPhone() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _uploading = true;
      _statusMsg = null;
    });
    try {
      final url = await _storage.uploadFile(File(result.files.single.path!), 'videos/${_selectedBatchId ?? "free"}');
      if (!mounted) return;
      setState(() {
        _link.text = url;
        _uploading = false;
        _statusMsg = 'Uploaded \u2014 now tap "Add video". (Note: a directly-uploaded video plays via the video_player package instead of YouTube \u2014 see README)';
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

  Future<void> _addVideo() async {
    if (_adding) return;
    if (!_isFree && _selectedFolderId == null) {
      setState(() => _statusMsg = 'Choose a folder \u2014 title and link/upload are both required.');
      return;
    }
    if (_title.text.trim().isEmpty || _link.text.trim().isEmpty) {
      setState(() => _statusMsg = 'Title and link/upload are both required.');
      return;
    }
    setState(() {
      _adding = true;
      _statusMsg = null;
    });
    String? thumbUrl;
    String? thumbNote;
    if (_thumbFile != null) {
      try {
        thumbUrl = await _imageUpload.uploadImage(_thumbFile!);
      } on ImageUploadNotConfiguredException catch (e) {
        thumbNote = e.message; // thumbnail is optional, video still gets added without it
      } catch (e) {
        thumbNote = 'Thumbnail upload failed ($e)';
      }
    }
    try {
      await _fs.addVideo(VideoModel(
        id: '',
        title: _title.text.trim(),
        thumbUrl: thumbUrl,
        youtubeLink: _link.text.trim(),
        batchId: _selectedBatchId,
        folderId: _selectedFolderId,
      ));
      _title.clear();
      _link.clear();
      if (mounted) {
        setState(() {
          _thumbFile = null;
          _statusMsg = thumbNote == null ? 'Video added.' : 'Video added without a thumbnail. $thumbNote';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Could not add the video: $e');
    }
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _deleteVideoConfirm(VideoModel v) async {
    final auto = v.source == 'youtube_auto';
    final ok = await _confirm(
      auto ? 'Hide video?' : 'Delete video?',
      auto
          ? '"${v.title}" was fetched automatically from your YouTube channel. It will be hidden from the app (it will not come back).'
          : 'Delete "${v.title}"?',
      action: auto ? 'Hide' : 'Delete',
    );
    if (!ok) return;
    try {
      await _fs.deleteVideo(v.id, batchId: v.batchId, source: v.source);
      if (mounted) setState(() => _statusMsg = auto ? 'Video hidden.' : 'Video deleted.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Could not do that: $e');
    }
  }

  Future<void> _renameFolder(String folderId, String currentName) async {
    final newName = await showRenameFolderDialog(context, currentName: currentName);
    if (newName == null) return;
    try {
      await _fs.renameVideoFolder(folderId, newName);
      if (mounted) setState(() => _statusMsg = 'Folder renamed.');
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Rename failed: $e');
    }
  }

  // Copies this folder (with all its videos) into other paid batches and / or
  // the free Video Classes in one go. The copy is independent of the original.
  Future<void> _copyFolder(VideoFolderModel f) async {
    List<BatchModel> batches;
    try {
      batches = await _fs.streamBatches().first.timeout(const Duration(seconds: 12));
    } catch (_) {
      if (mounted) setState(() => _statusMsg = 'Could not load the batch list \u2014 check your internet and try again.');
      return;
    }
    if (!mounted) return;
    final choice = await showCopyFolderDialog(
      context,
      folderName: f.name,
      freeLabel: 'Free Video Classes',
      batches: batches.where((b) => !b.mockOnly).toList(), // Mock Test Series batches have no videos
      alreadyIn: <String>{f.batchId == kFreeVideoBatchId ? kCopyFreeDest : f.batchId},
    );
    if (choice == null || !mounted) return;
    setState(() => _statusMsg = 'Copying "${f.name}" ...');
    try {
      final n = await _fs.copyVideoFolder(f.id, choice.destinations);
      final msg = 'Copied "${f.name}" ($n videos) to ${choice.destinations.length} place(s).';
      if (!mounted) return;
      setState(() => _statusMsg = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Copy failed: $e');
    }
  }

  Future<void> _deleteFolderConfirm(String folderId, String folderName) async {
    final ok = await _confirm('Delete folder?', 'Delete the folder "$folderName"? All videos inside it will be deleted too. This cannot be undone.');
    if (!ok) return;
    try {
      await _fs.deleteVideoFolder(folderId);
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
    final isFree = _isFree;
    // Free section with no folder chosen = loose videos (incl. the auto-fetched
    // YouTube ones). Those stay newest-first and are NOT arranged by hand.
    final loose = isFree && _selectedFolderId == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('1. Which section? (first choice = free Video Classes)', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        StreamBuilder<List<BatchModel>>(
          stream: _batchesStream,
          builder: (context, snap) {
            final batches = snap.data ?? <BatchModel>[];
            return DropdownButton<String?>(
              hint: Text('Free Video Classes', style: TextStyle(color: AppC.muted)),
              value: _validId(_selectedBatchId, batches.map((b) => b.id)),
              dropdownColor: AppC.card,
              isExpanded: true,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('Free Video Classes', style: TextStyle(color: AppC.text))),
                ...batches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.title, style: TextStyle(color: AppC.text)))),
              ],
              onChanged: (v) => setState(() {
                _selectedBatchId = v;
                _selectedFolderId = null;
              }),
            );
          },
        ),
        Divider(color: AppC.divider),
        Text(
          isFree ? '2. Folder (optional for free videos) \u2014 choose or create new' : '2. Choose a folder or create new',
          style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<VideoFolderModel>>(
          stream: _fs.streamVideoFolders(_selectedBatchId ?? kFreeVideoBatchId),
          builder: (context, snap) {
            final folders = snap.data ?? <VideoFolderModel>[];
            final selected = folders.where((f) => f.id == _selectedFolderId).toList();
            final folderRow = Row(children: [
              Expanded(
                child: DropdownButton<String?>(
                  hint: Text(isFree ? 'No folder (loose videos)' : 'Choose folder', style: TextStyle(color: AppC.muted)),
                  value: _validId(_selectedFolderId, folders.map((f) => f.id)),
                  dropdownColor: AppC.card,
                  isExpanded: true,
                  items: [
                    if (isFree) DropdownMenuItem<String?>(value: null, child: Text('No folder (loose videos)', style: TextStyle(color: AppC.text))),
                    ...folders.map((f) => DropdownMenuItem<String?>(value: f.id, child: Text(f.name, style: TextStyle(color: AppC.text)))),
                  ],
                  onChanged: (v) => setState(() => _selectedFolderId = v),
                ),
              ),
              if (_selectedFolderId != null && selected.isNotEmpty) ...[
                IconButton(tooltip: 'Copy this folder to other batches / Free Videos', icon: Icon(Icons.copy_all, color: AppC.sky, size: 20), onPressed: () => _copyFolder(selected.first)),
                IconButton(tooltip: 'Rename this folder', icon: Icon(Icons.edit, color: AppC.accent, size: 20), onPressed: () => _renameFolder(selected.first.id, selected.first.name)),
                IconButton(tooltip: 'Delete this folder', icon: Icon(Icons.delete, color: AppC.red, size: 20), onPressed: () => _deleteFolderConfirm(selected.first.id, selected.first.name)),
              ],
            ]);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                folderRow,
                if (folders.length >= 2)
                  AdminFolderOrderSection<VideoFolderModel>(
                    items: folders,
                    idOf: (f) => f.id,
                    labelOf: (f) => f.name,
                    onSave: (list) => _fs.saveOrder('videoFolders', list.map((f) => f.id).toList()),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _newFolderName, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'New folder name', hintStyle: TextStyle(color: AppC.muted)))),
          IconButton(icon: Icon(Icons.add_circle, color: AppC.accent), onPressed: _createFolder),
        ]),
        Divider(color: AppC.divider),
        Text('3. Add video', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: _pickThumb,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppC.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.line2)),
              child: _thumbFile != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_thumbFile!, fit: BoxFit.cover)) : Icon(Icons.image, color: AppC.muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _title, style: TextStyle(color: AppC.text), decoration: InputDecoration(hintText: 'Video title', hintStyle: TextStyle(color: AppC.muted)))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _link, style: TextStyle(color: AppC.text), decoration: InputDecoration(labelText: 'YouTube link (or upload from phone below)', labelStyle: TextStyle(color: AppC.muted))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _uploadVideoFromPhone,
          icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
          label: Text(_uploading ? 'Uploading...' : 'Upload video directly from phone'),
        ),
        if (_statusMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_statusMsg!, style: TextStyle(color: AppC.orange, fontSize: 12))),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _adding ? null : _addVideo,
          child: _adding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add video'),
        ),
        if (isFree || _selectedFolderId != null) ...[
          Divider(color: AppC.divider, height: 30),
          Text(
            isFree
                ? (_selectedFolderId == null ? 'Existing free videos (not in a folder)' : 'Existing videos in this folder')
                : 'Existing videos in this folder',
            style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<VideoModel>>(
            // A folder's videos come from the same stream the students' folder
            // screen uses, so the order shown here is the order students see.
            stream: loose ? _fs.streamFreeVideos() : _fs.streamVideosInFolder(_selectedFolderId!),
            builder: (context, snap) {
              if (snap.hasError) return Text('Could not load: ${snap.error}', style: TextStyle(color: AppC.orange, fontSize: 12));
              if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator()));
              final all = snap.data!;
              final videos = loose ? all.where((v) => v.folderId == null || v.folderId!.isEmpty).toList() : all;
              if (videos.isEmpty) return Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('There is no video here yet', style: TextStyle(color: AppC.muted, fontSize: 12)));
              if (loose) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('These stay newest-first. To arrange videos by hand, put them in a folder.', style: TextStyle(color: AppC.muted, fontSize: 11)),
                    ),
                    ...videos.map(_videoTile),
                  ],
                );
              }
              return AdminReorderList<VideoModel>(
                items: videos,
                idOf: (v) => v.id,
                onSave: (list) => _fs.saveOrder('videos', list.map((v) => v.id).toList()),
                contentBuilder: (context, v) => _videoTile(v),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _videoTile(VideoModel v) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: NetImage(url: v.thumbUrl, width: 56, height: 34, fallbackIcon: '🎬', radius: 6),
      title: Text(v.title, style: TextStyle(color: AppC.text, fontSize: 13)),
      subtitle: v.source == 'youtube_auto' ? Text('Auto-fetched from YouTube', style: TextStyle(color: AppC.muted, fontSize: 10.5)) : null,
      trailing: IconButton(
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        tooltip: v.source == 'youtube_auto' ? 'Hide' : 'Delete',
        icon: Icon(v.source == 'youtube_auto' ? Icons.visibility_off : Icons.delete, color: AppC.red, size: 18),
        onPressed: () => _deleteVideoConfirm(v),
      ),
    );
  }
}
