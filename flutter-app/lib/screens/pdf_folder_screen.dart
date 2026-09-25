import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import 'pdf_viewer_screen.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';

class PdfFolderScreen extends StatefulWidget {
  final PdfFolderModel folder;
  const PdfFolderScreen({super.key, required this.folder});

  @override
  State<PdfFolderScreen> createState() => _PdfFolderScreenState();
}

class _PdfFolderScreenState extends State<PdfFolderScreen> {
  final _fs = FirestoreService();
  late Stream<List<PdfModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamPdfsInFolder(widget.folder.id);
  }

  // Pull-down-to-refresh — separate from normal scrolling. Flutter only
  // fires this on an over-scroll gesture at the very top of the list.
  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamPdfsInFolder(widget.folder.id));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: StreamBuilder<List<PdfModel>>(
        stream: _stream,
        builder: (context, snap) {
          Widget content;
          if (snap.hasError) {
            content = PullableMessage(child: ErrorView(error: snap.error));
          } else if (!snap.hasData) {
            content = const PullableMessage(child: LoadingView());
          } else if (snap.data!.isEmpty) {
            content = const PullableMessage(child: EmptyView('No PDF in this folder yet'));
          } else {
            final pdfs = snap.data!;
            content = ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: pdfs.length,
              itemBuilder: (context, i) {
                final p = pdfs[i];
                return DepthCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  // Opens inside the app. Paid-batch folders (type 'batch') hide the
                  // "open outside the app" button so the link can't be copied out.
                  onTap: () => openPdfInApp(context, link: p.driveLink, title: p.title, allowExternalOpen: widget.folder.type != 'batch'),
                  child: ListTile(
                    leading: NetImage(url: p.iconUrl, width: 40, height: 40, fallbackIcon: '📄', radius: 8),
                    title: Text(p.title, style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
