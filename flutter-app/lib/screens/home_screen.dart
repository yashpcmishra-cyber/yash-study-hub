import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_globals.dart';
import '../services/firestore_service.dart';
import '../services/queries_service.dart';
import '../services/query_seen_store.dart';
import '../models/models.dart';
import '../models/query_model.dart';
import '../utils/open_link.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/depth_card.dart';
import '../widgets/banner_carousel.dart';
import 'pdf_library_screen.dart';
import 'video_classes_screen.dart';
import 'news_screen.dart';
import 'batches_screen.dart';
import 'mock_tests_screen.dart';
import 'my_course_screen.dart';
import 'queries_screen.dart';
import 'notifications_screen.dart';
import 'admin/admin_login_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _fs = FirestoreService();

  // The data streams are created ONCE (not on every rebuild), so Firestore
  // is not re-subscribed again and again. Pull-to-refresh recreates them.
  late Stream<AppConfigModel> _cfgStream;
  late Stream<List<BannerModel>> _bannersStream;
  late Stream<List<VideoModel>> _latestVideosStream;
  late Stream<List<VideoModel>> _fallbackVideosStream;
  late Stream<List<QueryModel>> _myQueriesStream; // for the red dot on the Queries tile
  Set<String> _seenReplies = <String>{};

  void _initStreams() {
    _cfgStream = _fs.streamAppConfig();
    _bannersStream = _fs.streamBanners();
    _latestVideosStream = _fs.streamLatestVideos();
    _fallbackVideosStream = _fs.streamAutoFetchedVideos();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _myQueriesStream = uid == null ? const Stream<List<QueryModel>>.empty() : QueriesService().streamMine(uid);
  }

  Future<void> _loadSeen() async {
    final seen = await QuerySeenStore.load();
    if (mounted) setState(() => _seenReplies = seen);
  }

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadSeen();
    // App was opened by tapping a push notification -> go straight to the
    // Notifications screen.
    if (openNotificationsOnStart) {
      openNotificationsOnStart = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      });
    }
  }

  // The app logo at the top-left of the header doubles as the hidden Admin
  // Login entry point: a long-press opens it. Nothing about it looks
  // tappable, so students never stumble onto it by accident.
  void _openAdminLogin(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeBody(),
      const NewsScreen(categories: ['banking', 'ssc', 'up_state', 'sports', 'technology', 'space', 'defence'], title: 'News'),
      const PdfLibraryScreen(),
      const NewsScreen(categories: ['national', 'hindi_news', 'hindi_ca'], title: 'Current Affairs'),
      const ProfileScreen(),
    ];

    // Back button: from News / PDFs / C.Affairs it goes back to the Home tab
    // first (instead of closing the whole app); from Home it closes the app.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: SafeArea(child: screens[_tab]),
        bottomNavigationBar: YshBottomNav(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? actionLabel, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel, style: const TextStyle(color: Color(0xFFFFFF29))),
            ),
        ],
      ),
    );
  }

  Widget _stripMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildHomeBody() {
    return StreamBuilder<AppConfigModel>(
      stream: _cfgStream,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data ?? const AppConfigModel();
        return StreamBuilder<List<BannerModel>>(
          stream: _bannersStream,
          builder: (context, bannerSnap) {
            final banners = bannerSnap.data ?? <BannerModel>[];
            return LayoutBuilder(
              builder: (context, box) {
                // Grid cells shrink/grow with the screen so that header +
                // banner + 3x2 grid + social card all fit WITHOUT scrolling.
                const sidePad = 14.0, gap = 10.0;
                final cellW = (box.maxWidth - sidePad * 2 - gap * 2) / 3;
                const headerH = 74.0; // logo row
                const socialH = 64.0 + 10; // social card + its top gap
                final bannerH = banners.isEmpty ? 0.0 : (box.maxWidth - sidePad * 2) * 9 / 16 + 14 + 14; // image + dots + gaps
                final free = box.maxHeight - headerH - bannerH - socialH - 14 /* grid top gap */ - gap - 8 /* bottom */;
                final cellH = (free / 2).clamp(78.0, 120.0).toDouble();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_initStreams);
                    await Future<void>.delayed(const Duration(milliseconds: 600));
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Long-press = hidden Admin Login (see _openAdminLogin).
                            GestureDetector(
                              onLongPress: () => _openAdminLogin(context),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  color: Colors.white,
                                  child: cfg.logoUrl != null
                                      ? Image.network(cfg.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🎓', style: TextStyle(fontSize: 24)))))
                                      : Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🎓', style: TextStyle(fontSize: 24)))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cfg.appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(cfg.tagline, style: const TextStyle(color: Color(0xFFFFFF29), fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Text('🔔', style: TextStyle(fontSize: 22)),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                            ),
                          ],
                        ),
                      ),

                      // Banner carousel (16:9, auto-scroll) — admin-managed.
                      if (banners.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                          child: BannerCarousel(banners: banners),
                        ),

                      // 3 x 2 quick access grid
                      Padding(
                        padding: const EdgeInsets.fromLTRB(sidePad, 14, sidePad, 0),
                        child: GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                          childAspectRatio: cellW / cellH,
                          children: [
                            _quickAccessCard('📝', 'Mock Tests', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MockTestsScreen()))),
                            _quickAccessCard('📚', 'PDF Library', () => setState(() => _tab = 2)),
                            _quickAccessCard('🎬', 'Video Classes', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoClassesScreen()))),
                            _quickAccessCard('🎓', 'Paid Batches', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatchesScreen()))),
                            _quickAccessCard('📖', 'My Course', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyCourseScreen()))),
                            StreamBuilder<List<QueryModel>>(
                              stream: _myQueriesStream,
                              builder: (context, qSnap) => _quickAccessCard(
                                '💬',
                                'Queries',
                                () async {
                                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QueriesScreen()));
                                  _loadSeen(); // the student has now seen the replies
                                },
                                dot: QuerySeenStore.hasUnread(qSnap.data ?? const <QueryModel>[], _seenReplies),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Social banner — auto-rotates between Telegram/WhatsApp/YouTube every 3s
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: _SocialRotator(cfg: cfg),
                      ),

                      // YouTube auto-fetch section — sits BELOW the social
                      // card, so it only shows when the student scrolls.
                      _sectionHeader(
                        'YouTube Videos',
                        actionLabel: 'Channel',
                        onAction: () => openExternalLink(context, cfg.youtubeUrl),
                      ),
                      SizedBox(
                        height: 130,
                        child: StreamBuilder<List<VideoModel>>(
                          stream: _latestVideosStream,
                          builder: (context, latestSnap) {
                            final latest = latestSnap.data ?? <VideoModel>[];
                            if (latest.isNotEmpty) return _videoStrip(context, latest);
                            return StreamBuilder<List<VideoModel>>(
                              stream: _fallbackVideosStream,
                              builder: (context, snap) {
                                if (snap.hasError) return _stripMessage('Could not load videos.');
                                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                final videos = snap.data!;
                                if (videos.isEmpty) return _stripMessage('New videos will show up here.');
                                return _videoStrip(context, videos);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _videoStrip(BuildContext context, List<VideoModel> videos) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: videos.length,
      itemBuilder: (context, i) {
        final v = videos[i];
        return DepthCard(
          onTap: () => openExternalLink(context, v.youtubeLink),
          margin: const EdgeInsets.only(right: 10),
          pressScale: 0.93,
          pressBrighten: 0.08,
          child: SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                v.thumbUrl != null && v.thumbUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: v.thumbUrl!,
                        height: 78,
                        width: 140,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(height: 78, color: const Color(0xFF1D3184), alignment: Alignment.center, child: const Text('▶️', style: TextStyle(fontSize: 26))),
                      )
                    : Container(height: 78, color: const Color(0xFF1D3184), alignment: Alignment.center, child: const Text('▶️', style: TextStyle(fontSize: 26))),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickAccessCard(String emoji, String label, VoidCallback onTap, {bool dot = false}) {
    final card = DepthCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      pressScale: 0.93,
      pressBrighten: 0.08,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    if (!dot) return card;
    // Red dot (top-right corner) = there is a reply the student has not seen.
    return Stack(
      children: [
        Positioned.fill(child: card),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF081136), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Telegram / WhatsApp / YouTube tile that flips to the next one every
/// 3 seconds. It owns its own timer so that only THIS small widget redraws
/// (not the whole Home screen).
class _SocialRotator extends StatefulWidget {
  final AppConfigModel cfg;
  const _SocialRotator({required this.cfg});

  @override
  State<_SocialRotator> createState() => _SocialRotatorState();
}

class _SocialRotatorState extends State<_SocialRotator> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _idx = (_idx + 1) % 3); // 3 fixed socials
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.cfg;
    final socials = <Map<String, dynamic>>[
      {'title': 'Official Telegram', 'sub': 'Instant updates & PDFs', 'cta': 'Join', 'color': const Color(0xFF2AABEE), 'icon': Icons.send, 'url': cfg.telegramUrl},
      {'title': 'Official WhatsApp', 'sub': 'Fastest notifications', 'cta': 'Follow', 'color': const Color(0xFF25D366), 'icon': Icons.chat, 'url': cfg.whatsappUrl},
      {'title': 'Official YouTube', 'sub': 'Free live classes', 'cta': 'Sub', 'color': const Color(0xFFFF0000), 'icon': Icons.play_circle_fill, 'url': cfg.youtubeUrl},
    ];
    final s = socials[_idx];
    final Color color = s['color'] as Color;
    return GestureDetector(
      onTap: () => openExternalLink(context, s['url'] as String),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.4))),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color, child: Icon(s['icon'] as IconData, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(s['sub'] as String, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
              child: Text(s['cta'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
