import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/open_link.dart';

/// Opens a PDF INSIDE the app (instead of sending the student to Drive / the
/// browser).
///
///  * A Google Drive FILE link (share link, "open?id=", "uc?id=") is shown
///    with Drive's own preview page. The file must be shared as
///    "Anyone with the link - Viewer".
///  * Any other http(s) link (for example a Firebase Storage download URL)
///    is shown through Google's document viewer.
///  * A Drive FOLDER / Google Docs link cannot be previewed as one file, so
///    for free PDFs it opens outside the app as before.
///
/// [allowExternalOpen] = false is used for PAID-BATCH PDFs: the
/// "open outside the app" button is hidden and the viewer refuses to jump to
/// Drive's own "open / download" pages, so a student cannot easily copy or
/// share the link from there. Free PDFs keep the button (default = true).
Future<void> openPdfInApp(
  BuildContext context, {
  required String link,
  required String title,
  bool allowExternalOpen = true,
}) async {
  void snack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  final text = link.trim();
  final uri = Uri.tryParse(text);
  if (text.isEmpty || uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    snack('This PDF link is not valid. / Ye PDF link sahi nahi hai.');
    return;
  }

  final String viewUrl;
  final fileId = _driveFileId(uri);
  if (fileId != null) {
    viewUrl = 'https://drive.google.com/file/d/$fileId/preview';
  } else if (uri.host == 'drive.google.com' || uri.host == 'docs.google.com') {
    // A Drive folder or a Google Doc/Sheet link — cannot be shown as one PDF.
    if (allowExternalOpen) {
      await openExternalLink(context, text);
    } else {
      snack('This link cannot be opened inside the app. Ask the admin to add the PDF\u2019s own Drive file link. / Admin se PDF ka apna Drive file link lagwao.');
    }
    return;
  } else {
    viewUrl = 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(text)}';
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfViewerScreen(title: title, viewUrl: viewUrl, originalUrl: text, allowExternalOpen: allowExternalOpen),
    ),
  );
}

/// The file id of a Google Drive FILE link, or null if this is not one.
String? _driveFileId(Uri uri) {
  if (uri.host != 'drive.google.com') return null;
  final m = RegExp(r'/file/(?:u/\d+/)?d/([A-Za-z0-9_-]+)').firstMatch(uri.path);
  if (m != null) return m.group(1);
  final id = uri.queryParameters['id'];
  if (id != null && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return id;
  return null;
}

bool _isGoogleHost(String host) {
  return host == 'google.com' ||
      host.endsWith('.google.com') ||
      host.endsWith('.googleusercontent.com') ||
      host.endsWith('.gstatic.com');
}

// Drive's own "view / edit / open / download" pages (NOT the /preview page).
bool _isDriveOpenPage(Uri uri) {
  if (uri.host != 'drive.google.com' && uri.host != 'docs.google.com') return false;
  final p = uri.path;
  return p.endsWith('/view') || p.endsWith('/edit') || p.startsWith('/open') || p.startsWith('/uc');
}

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String viewUrl; // the page that is shown inside the app
  final String originalUrl; // what the "open outside the app" button opens
  final bool allowExternalOpen;
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.viewUrl,
    required this.originalUrl,
    this.allowExternalOpen = true,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onWebResourceError: (error) {
            // Only a failure of the main page matters (small inner files can fail silently).
            if (error.isForMainFrame == true && mounted) setState(() => _failed = true);
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(widget.viewUrl));
  }

  // Keeps the viewer on Google's own viewer pages. Links to other sites, and
  // (for paid PDFs) Drive's "open / download" pages, are refused.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (!request.isMainFrame) return NavigationDecision.navigate; // parts inside the viewer page
    final uri = Uri.tryParse(request.url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return NavigationDecision.prevent;
    if (!_isGoogleHost(uri.host)) return NavigationDecision.prevent;
    if (!widget.allowExternalOpen && _isDriveOpenPage(uri)) return NavigationDecision.prevent;
    return NavigationDecision.navigate;
  }

  void _reload() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(widget.viewUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh), onPressed: _reload),
          if (widget.allowExternalOpen)
            IconButton(
              tooltip: 'Open outside the app',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternalLink(context, widget.originalUrl),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_progress < 100 && !_failed)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3, color: Color(0xFFFFFF29), backgroundColor: Colors.transparent),
            ),
          if (_failed)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF050B24),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.white38, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load this PDF. Check your internet connection and try again. / PDF load nahi hui. Internet check karke dobara try karo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(onPressed: _reload, child: const Text('Try again')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
