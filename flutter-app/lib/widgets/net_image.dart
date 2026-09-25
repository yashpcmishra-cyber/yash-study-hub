import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
        color: const Color(0xFF192B72),
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
      child: CachedNetworkImage(
        imageUrl: u,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _fallback(),
        errorWidget: (context, url, error) => _fallback(),
      ),
    );
  }
}
