import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/image_upload_service.dart';
import '../../models/models.dart';
import '../../widgets/net_image.dart';

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
        backgroundColor: const Color(0xFF081136),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('1. Which section? (first choice = free Video Classes)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        StreamBuilder<List<BatchModel>>(
          stream: _batchesStream,
          builder: (context, snap) {
            final batches = snap.data ?? <BatchModel>[];
            return DropdownButton<String?>(
              hint: const Text('Free Video Classes', style: TextStyle(color: Colors.grey)),
              value: _validId(_selectedBatchId, batches.map((b) => b.id)),
              dropdownColor: const Color(0xFF081136),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Free Video Classes', style: TextStyle(color: Colors.white))),
                ...batches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.title, style: const TextStyle(color: Colors.white)))),
              ],
              onChanged: (v) => setState(() {
                _selectedBatchId = v;
                _selectedFolderId = null;
              }),
            );
          },
        ),
        const Divider(color: Colors.grey),
        Text(
          isFree ? '2. Folder (optional for free videos) \u2014 choose or create new' : '2. Choose a folder or create new',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<VideoFolderModel>>(
          stream: _fs.streamVideoFolders(_selectedBatchId ?? kFreeVideoBatchId),
          builder: (context, snap) {
            final folders = snap.data ?? <VideoFolderModel>[];
            final selected = folders.where((f) => f.id == _selectedFolderId).toList();
            return Row(children: [
              Expanded(
                child: DropdownButton<String?>(
                  hint: Text(isFree ? 'No folder (loose videos)' : 'Choose folder', style: const TextStyle(color: Colors.grey)),
                  value: _validId(_selectedFolderId, folders.map((f) => f.id)),
                  dropdownColor: const Color(0xFF081136),
                  isExpanded: true,
                  items: [
                    if (isFree) const DropdownMenuItem<String?>(value: null, child: Text('No folder (loose videos)', style: TextStyle(color: Colors.white))),
                    ...folders.map((f) => DropdownMenuItem<String?>(value: f.id, child: Text(f.name, style: const TextStyle(color: Colors.white)))),
                  ],
                  onChanged: (v) => setState(() => _selectedFolderId = v),
                ),
              ),
              if (_selectedFolderId != null && selected.isNotEmpty)
                IconButton(tooltip: 'Delete this folder', icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deleteFolderConfirm(selected.first.id, selected.first.name)),
            ]);
          },
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _newFolderName, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'New folder name', hintStyle: TextStyle(color: Colors.grey)))),
          IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFFFFF29)), onPressed: _createFolder),
        ]),
        const Divider(color: Colors.grey),
        const Text('3. Add video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: _pickThumb,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFF050B24), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade800)),
              child: _thumbFile != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_thumbFile!, fit: BoxFit.cover)) : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _title, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Video title', hintStyle: TextStyle(color: Colors.grey)))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _link, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'YouTube link (or upload from phone below)', labelStyle: TextStyle(color: Colors.grey))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _uploadVideoFromPhone,
          icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
          label: Text(_uploading ? 'Uploading...' : 'Upload video directly from phone'),
        ),
        if (_statusMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_statusMsg!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _adding ? null : _addVideo,
          child: _adding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add video'),
        ),
        if (isFree || _selectedFolderId != null) ...[
          const Divider(color: Colors.grey, height: 30),
          Text(
            isFree
                ? (_selectedFolderId == null ? 'Existing free videos (not in a folder)' : 'Existing videos in this folder')
                : 'Existing videos in this folder',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<VideoModel>>(
            stream: isFree ? _fs.streamFreeVideos() : _fs.streamVideosInFolder(_selectedFolderId!),
            builder: (context, snap) {
              if (snap.hasError) return Text('Could not load: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12));
              if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator()));
              final all = snap.data!;
              final videos = isFree
                  ? all.where((v) => _selectedFolderId == null ? (v.folderId == null || v.folderId!.isEmpty) : v.folderId == _selectedFolderId).toList()
                  : all;
              if (videos.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('There is no video here yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
              return Column(
                children: videos
                    .map((v) => ListTile(
                          dense: true,
                          leading: NetImage(url: v.thumbUrl, width: 56, height: 34, fallbackIcon: '🎬', radius: 6),
                          title: Text(v.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: v.source == 'youtube_auto' ? const Text('Auto-fetched from YouTube', style: TextStyle(color: Colors.grey, fontSize: 10.5)) : null,
                          trailing: IconButton(
                            tooltip: v.source == 'youtube_auto' ? 'Hide' : 'Delete',
                            icon: Icon(v.source == 'youtube_auto' ? Icons.visibility_off : Icons.delete, color: Colors.redAccent, size: 18),
                            onPressed: () => _deleteVideoConfirm(v),
                          ),
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
