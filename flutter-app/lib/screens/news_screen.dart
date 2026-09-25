import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../utils/open_link.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';

class NewsScreen extends StatefulWidget {
  final List<String> categories;
  final String title;
  const NewsScreen({super.key, required this.categories, required this.title});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _fs = FirestoreService();
  late Stream<List<NewsItemModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamNews(widget.categories);
  }

  // News is live (it updates by itself); pulling down just reconnects it.
  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamNews(widget.categories));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<List<NewsItemModel>>(
        stream: _stream,
        builder: (context, snap) {
          Widget content;
          if (snap.hasError) {
            content = PullableMessage(child: ErrorView(error: snap.error));
          } else if (!snap.hasData) {
            content = const PullableMessage(child: LoadingView());
          } else if (snap.data!.isEmpty) {
            content = const PullableMessage(child: EmptyView('No news yet \u2014 please check back later'));
          } else {
            final items = snap.data!;
            content = ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                return DepthCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () => openExternalLink(context, n.link),
                  child: ListTile(
                    leading: NetImage(url: n.image, width: 50, height: 50, fallbackIcon: '📰', radius: 6),
                    title: Text(n.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(n.categoryLabel, style: const TextStyle(color: Color(0xFFFFFF29), fontSize: 10.5)),
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
