import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../utils/open_link.dart';

/// Auto-scrolling 16:9 image slider for the Home screen, fed entirely by
/// whatever banners the admin has uploaded (Admin Panel -> Banners tab).
/// Renders nothing at all when there are no banners yet, so a fresh
/// install with an empty `banners` collection never shows blank space.
class BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;
  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2) return; // nothing to auto-scroll between
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      if (next == 0) {
        // Wrap around to the first slide without a fast rewind through all slides.
        _controller.jumpToPage(0);
      } else {
        _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void didUpdateWidget(covariant BannerCarousel old) {
    super.didUpdateWidget(old);
    // Admin can add/delete banners live (Firestore stream) — keep the
    // index in range and restart the timer against the new count.
    if (old.banners.length != widget.banners.length) {
      if (_index >= widget.banners.length) _index = 0;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final b = widget.banners[i];
                return GestureDetector(
                  onTap: b.linkUrl != null ? () => openExternalLink(context, b.linkUrl) : null,
                  child: CachedNetworkImage(
                    imageUrl: b.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(color: const Color(0xFF101D57)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF101D57),
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _index == i ? const Color(0xFFFFFF29) : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
