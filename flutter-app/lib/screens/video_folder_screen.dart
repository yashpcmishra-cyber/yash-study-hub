import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';
import 'video_player_screen.dart';

/// Videos inside one folder of the free Video Classes section.
class VideoFolderScreen extends StatefulWidget {
  final VideoFolderModel folder;
  const VideoFolderScreen({super.key, required this.folder});

  @override
  State<VideoFolderScreen> createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<VideoFolderScreen> {
  final _fs = FirestoreService();
  late Stream<List<VideoModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamVideosInFolder(widget.folder.id);
  }

  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamVideosInFolder(widget.folder.id));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: StreamBuilder<List<VideoModel>>(
        stream: _stream,
        builder: (context, snap) {
          Widget content;
          if (snap.hasError) {
            content = PullableMessage(child: ErrorView(error: snap.error));
          } else if (!snap.hasData) {
            content = const PullableMessage(child: LoadingView());
          } else if (snap.data!.isEmpty) {
            content = const PullableMessage(child: EmptyView('No video in this folder yet'));
          } else {
            final videos = snap.data!;
            content = ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: videos.length,
              itemBuilder: (context, i) {
                final v = videos[i];
                return DepthCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VideoPlayerScreen(youtubeUrl: v.youtubeLink, title: v.title)),
                  ),
                  child: ListTile(
                    leading: NetImage(url: v.thumbUrl, width: 64, height: 40, fallbackIcon: '🎬', radius: 6),
                    title: Text(v.title, style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            );
          }
          return RefreshIndicator(onRefresh: _refresh, child: content);
        },
      ),
    );
  }
}
