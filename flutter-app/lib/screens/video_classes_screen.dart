import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';
import 'video_folder_screen.dart';
import 'video_player_screen.dart';

/// Free "Video Classes": folders first (if the admin created any), then the
/// videos that are not inside a folder (newest first).
class VideoClassesScreen extends StatefulWidget {
  const VideoClassesScreen({super.key});

  @override
  State<VideoClassesScreen> createState() => _VideoClassesScreenState();
}

class _VideoClassesScreenState extends State<VideoClassesScreen> {
  final _fs = FirestoreService();
  late Stream<List<VideoModel>> _videosStream; // YouTube channel videos (latest 10)
  late Stream<List<VideoModel>> _looseStream; // videos added by hand without a folder (best effort)
  late Stream<List<VideoFolderModel>> _foldersStream;
  final Map<String, Future<int>> _counts = {};

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    // Main list: the query "source == youtube_auto" is explicitly allowed by
    // the Firestore rules for every logged-in student, so it never fails.
    _videosStream = _fs.streamAutoFetchedVideos(limit: 10);
    // Extra: free videos the admin added by hand without a folder. If the
    // rules refuse this query for a student it is simply skipped (no error
    // screen), see build().
    _looseStream = _fs.streamFreeVideos(limitYoutubeAuto: 0);
    _foldersStream = _fs.streamFreeVideoFolders();
    _counts.clear();
  }

  Future<void> _refresh() async {
    setState(_initStreams);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Classes')),
      body: StreamBuilder<List<VideoModel>>(
        stream: _videosStream,
        builder: (context, vSnap) {
          if (vSnap.hasError) {
            return RefreshIndicator(onRefresh: _refresh, child: PullableMessage(child: ErrorView(error: vSnap.error)));
          }
          if (!vSnap.hasData) return const LoadingView();
          final auto = vSnap.data!;
          return StreamBuilder<List<VideoModel>>(
            stream: _looseStream,
            builder: (context, lSnap) {
          return StreamBuilder<List<VideoFolderModel>>(
            stream: _foldersStream,
            builder: (context, fSnap) {
              // If folders (or the hand-added loose videos) fail to load,
              // still show the YouTube videos.
              final folders = fSnap.data ?? <VideoFolderModel>[];
              final loose = (lSnap.data ?? <VideoModel>[])
                  .where((v) => v.source != 'youtube_auto' && (v.folderId == null || v.folderId!.isEmpty));
              final ungrouped = <VideoModel>[...loose, ...auto]..sort(compareVideosNewestFirst);
              Widget content;
              if (folders.isEmpty && ungrouped.isEmpty) {
                content = const PullableMessage(child: EmptyView('No video found'));
              } else {
                content = ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    for (final f in folders)
                      DepthCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoFolderScreen(folder: f))),
                        child: ListTile(
                          leading: const Text('📁', style: TextStyle(fontSize: 22)),
                          title: Text(f.name, style: const TextStyle(color: Colors.white)),
                          subtitle: FutureBuilder<int>(
                            future: _counts.putIfAbsent(f.id, () => _fs.countVideosInFolder(f.id)),
                            builder: (context, cSnap) => Text(
                              cSnap.hasData ? '${cSnap.data} videos' : '',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        ),
                      ),
                    if (folders.isNotEmpty && ungrouped.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(2, 10, 2, 8),
                        child: Text('Videos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    for (final v in ungrouped)
                      DepthCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => VideoPlayerScreen(youtubeUrl: v.youtubeLink, title: v.title)),
                        ),
                        child: ListTile(
                          leading: NetImage(url: v.thumbUrl, width: 64, height: 40, fallbackIcon: '🎬', radius: 6),
                          title: Text(v.title, style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                );
              }
              return RefreshIndicator(onRefresh: _refresh, child: content);
            },
          );
            },
          );
        },
      ),
    );
  }
}
