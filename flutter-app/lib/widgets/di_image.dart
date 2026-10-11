import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// DI graph / table picture shown above the questions of a DI group.
/// Tap = full screen with pinch-to-zoom (small numbers are hard to read on a phone).
class DiImage extends StatelessWidget {
  final String url;
  const DiImage({super.key, required this.url});

  void _zoom(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Pinch to zoom', style: TextStyle(fontSize: 14)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (c, u) => const CircularProgressIndicator(strokeWidth: 2),
              errorWidget: (c, u, e) => const Text('Image could not load', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _zoom(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (c, u) => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (c, u, e) => const SizedBox(
                height: 80,
                child: Center(child: Text('Image could not load. Check internet.', style: TextStyle(color: Colors.black54, fontSize: 12))),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.zoom_in, size: 14, color: Colors.white),
                  SizedBox(width: 3),
                  Text('Zoom', style: TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
