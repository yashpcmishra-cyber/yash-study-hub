import 'dart:async';
import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Small rounded picture from a web link, with an icon shown when there is
/// no link, while loading, or if the picture fails to load.
class NetImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final String fallbackIcon; // a real emoji, e.g. '📁' — already colorful, no tint needed
  final double radius;

  const NetImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.fallbackIcon,
    this.radius = 8,
  });

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppC.chip,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        fallbackIcon,
        style: TextStyle(fontSize: height * 0.55),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.trim().isEmpty) return _fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SafeNetImage(
        url: u,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: (width * 3).round(),
        placeholder: (context) => _fallback(),
        error: (context) => _fallback(),
      ),
    );
  }
}


/// Network picture that does NOT use cached_network_image / path_provider /
/// sqflite. Reason: newer path_provider_android versions use JNI, and in the
/// release APK that can make the image cache hang forever (banners spinning,
/// thumbnails / PDF logos blank). This widget uses Flutter's own
/// Image.network (memory cache only), so it works whatever the plugins do.
/// If a load fails (weak network) it quietly retries up to 2 more times.
class SafeNetImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? error;

  const SafeNetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.placeholder,
    this.error,
  });

  @override
  State<SafeNetImage> createState() => _SafeNetImageState();
}

class _SafeNetImageState extends State<SafeNetImage> {
  int _attempt = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant SafeNetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _attempt >= 2) return;
    _retryTimer = Timer(const Duration(seconds: 3), () {
      _retryTimer = null;
      if (mounted) setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      key: ValueKey('${widget.url}#$_attempt'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return widget.placeholder?.call(context) ?? SizedBox(width: widget.width, height: widget.height);
      },
      errorBuilder: (context, err, stack) {
        _scheduleRetry();
        return widget.error?.call(context) ?? SizedBox(width: widget.width, height: widget.height);
      },
    );
  }
}
