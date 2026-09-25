import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_globals.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../utils/open_link.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/depth_card.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/net_image.dart';
import 'pdf_library_screen.dart';
import 'video_classes_screen.dart';
import 'news_screen.dart';
import 'batches_screen.dart';
import 'mock_tests_screen.dart';
import 'mock_test_list_screen.dart';
import 'batch_detail_screen.dart';
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
  late Stream<List<MockTestFolderModel>> _mockFoldersStream;
  late Stream<List<BatchModel>> _batchesStream;
  late Stream<List<VideoModel>> _latestVideosStream;
  late Stream<List<VideoModel>> _fallbackVideosStream;

  void _initStreams() {
    _cfgStream = _fs.streamAppConfig();
    _bannersStream = _fs.streamBanners();
    _mockFoldersStream = _fs.streamMockFolders();
    _batchesStream = _fs.streamBatches();
    _latestVideosStream = _fs.streamLatestVideos();
    _fallbackVideosStream = _fs.streamAutoFetchedVideos();
  }

  @override
  void initState() {
    super.initState();
    _initStreams();
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
                    // Looks and behaves exactly like a normal logo otherwise.
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

              // Welcome banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29), Color(0xFFE6E600)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome to\n${cfg.appName}', style: const TextStyle(color: Color(0xFF081136), fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 6),
                    const Text('Your journey to success begins here.', style: TextStyle(color: Color(0xFF101D57), fontSize: 12.5)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const NewsScreen(categories: ['hindi_ca'], title: 'Current Affairs'))),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF050B24), foregroundColor: const Color(0xFFFFFF29)),
                      child: const Text("Read Today's CA"),
                    ),
                  ],
                ),
              ),

              // Banner carousel (16:9, auto-scroll) — admin-managed, Admin Panel ->
              // Banners. Shows nothing until at least one banner is uploaded.
              StreamBuilder<List<BannerModel>>(
                stream: _bannersStream,
                builder: (context, snap) {
                  final banners = snap.data ?? <BannerModel>[];
                  if (banners.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: BannerCarousel(banners: banners),
                  );
                },
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(14, 18, 14, 4),
                child: Text('Quick Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [
                    _quickAccessCard('📝', 'Mock Tests', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MockTestsScreen()))),
                    _quickAccessCard('📚', 'PDF Library', () => setState(() => _tab = 2)),
                    _quickAccessCard('🎬', 'Video Classes', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoClassesScreen()))),
                    _quickAccessCard('🎓', 'Paid Batches', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatchesScreen()))),
                  ],
                ),
              ),

              // Social banner — auto-rotates between Telegram/WhatsApp/YouTube every 3s
              // (it has its own timer, so only this small tile redraws).
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: _SocialRotator(cfg: cfg),
              ),

              // Mock Tests section
              _sectionHeader(
                'Mock Tests',
                actionLabel: 'View All',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MockTestsScreen())),
              ),
              SizedBox(
                height: 90,
                child: StreamBuilder<List<MockTestFolderModel>>(
                  stream: _mockFoldersStream,
                  builder: (context, snap) {
                    if (snap.hasError) return _stripMessage('Could not load mock tests.');
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final folders = snap.data!;
                    if (folders.isEmpty) return _stripMessage('No mock tests yet.');
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: folders.length,
                      itemBuilder: (context, i) {
                        final f = folders[i];
                        return DepthCard(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MockTestListScreen(folder: f))),
                          margin: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 130,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('📝', style: TextStyle(fontSize: 22)),
                                  const SizedBox(height: 8),
                                  Text(f.examName, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Paid Batches preview
              _sectionHeader(
                'Paid Batches',
                actionLabel: 'View All',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatchesScreen())),
              ),
              SizedBox(
                height: 160,
                child: StreamBuilder<List<BatchModel>>(
                  stream: _batchesStream,
                  builder: (context, snap) {
                    if (snap.hasError) return _stripMessage('Could not load batches.');
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final batches = snap.data!;
                    if (batches.isEmpty) return _stripMessage('No batches yet.');
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: batches.length,
                      itemBuilder: (context, i) {
                        final b = batches[i];
                        return DepthCard(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batch: b))),
                          margin: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 150,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  NetImage(url: b.iconUrl, width: 34, height: 34, fallbackIcon: '🎓', radius: 8),
                                  const SizedBox(height: 10),
                                  Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  const Spacer(),
                                  if (b.hasValidity)
                                    Text(b.validityLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                                  Text('\u20b9${b.price}', style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // YouTube auto-fetch section (newest videos of the channel)
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
                    // The "latest videos" list is not there yet — use the
                    // plain list of auto-fetched videos instead.
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

  Widget _quickAccessCard(String emoji, String label, VoidCallback onTap) {
    return DepthCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
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
