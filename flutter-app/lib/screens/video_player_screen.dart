import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:chewie/chewie.dart';
import '../utils/open_link.dart';

/// In-built video player: playback speed, fullscreen with auto-rotate, and
/// proper stop when the user presses back — handled by disposing the
/// controllers in dispose(), which stops playback immediately and returns
/// to whichever screen opened this player.
///
/// Handles BOTH:
///  - YouTube links (Unlisted/Public) -> youtube_player_flutter
///  - Directly-uploaded video files (Firebase Storage URLs) -> chewie/video_player
///
/// If a YouTube video does not allow playing inside other apps, the
/// "Open in YouTube" button under the player opens it in the YouTube app.
///
/// [allowExternalOpen] = false is used for PAID-BATCH videos: the "Open in
/// YouTube" / "Try opening the link" buttons are hidden, so a student cannot
/// jump out to YouTube and copy/share the (Unlisted) link from there.
/// Free videos keep the buttons (default = true).
class VideoPlayerScreen extends StatefulWidget {
  final String youtubeUrl; // holds either a YouTube link or a direct video file URL
  final String title;
  final bool allowExternalOpen;
  const VideoPlayerScreen({super.key, required this.youtubeUrl, required this.title, this.allowExternalOpen = true});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  YoutubePlayerController? _ytController;
  vp.VideoPlayerController? _vpController;
  ChewieController? _chewieController;
  String? _error;
  bool get _isYoutube => widget.youtubeUrl.contains('youtube.com') || widget.youtubeUrl.contains('youtu.be');

  @override
  void initState() {
    super.initState();
    if (_isYoutube) {
      final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? '';
      if (videoId.isEmpty) {
        _error = 'This YouTube link is not valid.';
      } else {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: true, mute: false, enableCaption: true),
        );
      }
    } else {
      final uri = Uri.tryParse(widget.youtubeUrl.trim());
      if (uri == null || !uri.hasScheme) {
        _error = 'This video link is not valid.';
      } else {
        final controller = vp.VideoPlayerController.networkUrl(uri);
        _vpController = controller;
        controller.initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: controller,
              autoPlay: true,
              looping: false,
              allowFullScreen: true, // handles auto-rotate on fullscreen
              allowPlaybackSpeedChanging: true, // speed control (0.5x - 2x)
              materialProgressColors: ChewieProgressColors(playedColor: const Color(0xFFFFFF29), handleColor: const Color(0xFFFFFF29)),
            );
          });
        }).catchError((_) {
          // Bad/expired link, no internet, etc. — show a message instead
          // of leaving the student stuck on a spinner forever.
          if (mounted) setState(() => _error = 'Video failed to load. Check the link or try again.');
        });
      }
    }
  }

  @override
  void dispose() {
    // Stops playback the moment the user presses back / leaves the screen.
    _ytController?.pause();
    _ytController?.dispose();
    _chewieController?.pause();
    _chewieController?.dispose();
    _vpController?.dispose();
    super.dispose();
  }

  Widget _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              if (widget.allowExternalOpen) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => openExternalLink(context, widget.youtubeUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Try opening the link'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isYoutube) {
      final controller = _ytController;
      if (controller == null) return _errorScaffold(_error ?? 'This YouTube link is not valid.');
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFFFFFF29),
          onEnded: (_) => controller.pause(),
          bottomActions: [
            CurrentPosition(),
            ProgressBar(isExpanded: true, colors: const ProgressBarColors(playedColor: Color(0xFFFFFF29), handleColor: Color(0xFFFFFF29))),
            const PlaybackSpeedButton(),
            RemainingDuration(),
            FullScreenButton(),
          ],
        ),
        builder: (context, player) => Scaffold(
          appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
          body: Column(
            children: [
              player,
              if (widget.allowExternalOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: () => openExternalLink(context, widget.youtubeUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open in YouTube'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Directly-uploaded video (Firebase Storage) via Chewie
    if (_error != null) return _errorScaffold(_error!);
    final chewie = _chewieController;
    final vpc = _vpController;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: chewie != null && vpc != null
            ? AspectRatio(aspectRatio: vpc.value.aspectRatio, child: Chewie(controller: chewie))
            : const CircularProgressIndicator(),
      ),
    );
  }
}
