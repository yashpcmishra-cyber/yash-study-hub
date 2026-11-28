import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/open_link.dart';
import '../widgets/space_background.dart';
import '../app_colors.dart';
import '../services/download_store.dart';
import 'downloads_screen.dart';

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
///
/// The Download button saves the PDF INSIDE the app (private app storage, shown
/// on Home > Downloads) - never to the phone's own storage (same as the Web).
Future<void> openPdfInApp(
  BuildContext context, {
  required String link,
  required String title,
  bool allowExternalOpen = true,
  bool allowDownload = true,
}) async {
  void snack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  final text = link.trim();
  final uri = Uri.tryParse(text);
  if (text.isEmpty || uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    snack('This PDF link is not valid. / यह PDF लिंक सही नहीं है।');
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
      snack('This link cannot be opened inside the app. Ask the admin to add the PDF\u2019s own Drive file link. / एडमिन से PDF का अपना Drive फ़ाइल लिंक लगवाएँ।');
    }
    return;
  } else {
    viewUrl = 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(text)}';
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfViewerScreen(
        title: title,
        viewUrl: viewUrl,
        originalUrl: text,
        allowExternalOpen: allowExternalOpen,
        allowDownload: allowDownload,
      ),
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

// Lets the student pinch-zoom (two fingers) and double-tap zoom inside the
// viewer page, even if the page itself tries to block zooming.
const String _zoomJs = '''
(function () {
  var c = 'width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=6.0, user-scalable=yes';
  var m = document.querySelector('meta[name=viewport]');
  if (!m) {
    m = document.createElement('meta');
    m.name = 'viewport';
    if (document.head) document.head.appendChild(m);
  }
  m.setAttribute('content', c);
})();
''';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String viewUrl; // the page that is shown inside the app
  final String originalUrl; // what the "open outside the app" button opens
  final bool allowExternalOpen;
  final bool allowDownload; // shows the Download button in the top bar
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.viewUrl,
    required this.originalUrl,
    this.allowExternalOpen = true,
    this.allowDownload = true,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;
  bool _downloading = false;
  double _dlProgress = 0; // 0..1 (0 = unknown)
  bool _saved = false; // already in the app's Downloads
  bool _landscape = false;
  bool _controlsOpen = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => spaceBackgroundPause.value++);
    DownloadStore.changes.addListener(_checkSaved);
    _checkSaved();
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
          onPageFinished: (_) {
            _enablePinchZoom();
            // The viewer draws its pages a moment later, so apply once more.
            Future.delayed(const Duration(seconds: 2), _enablePinchZoom);
          },
          onWebResourceError: (error) {
            // Only a failure of the main page matters (small inner files can fail silently).
            if (error.isForMainFrame == true && mounted) setState(() => _failed = true);
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(widget.viewUrl));
    // Android WebView: allow zoom gestures (safe no-op on other platforms).
    try {
      (_controller.platform as dynamic).enableZoom(true);
    } catch (_) {}
  }

  @override
  void dispose() {
    DownloadStore.changes.removeListener(_checkSaved);
    // Give the phone's status/navigation bars back when leaving the PDF.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Future.microtask(() => spaceBackgroundPause.value--);
    super.dispose();
  }

  void _enablePinchZoom() {
    if (!mounted) return;
    try {
      _controller.runJavaScript(_zoomJs);
    } catch (_) {}
  }

  // Landscape = full-screen PDF: hide the top bar and the phone's system bars.
  void _applyOrientation(bool landscape) {
    if (landscape == _landscape) return;
    _landscape = landscape;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (landscape) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
        if (_controlsOpen) setState(() => _controlsOpen = false);
      }
    });
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // The address the real PDF file is fetched from.
  String _downloadUrl() {
    final text = widget.originalUrl.trim();
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final id = _driveFileId(uri);
      if (id != null) return 'https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t';
    }
    return text;
  }

  // Is PDF already in the app's Downloads? (changes the download icon)
  Future<void> _checkSaved() async {
    try {
      final it = await DownloadStore.find(widget.originalUrl);
      final saved = it != null;
      if (mounted && saved != _saved) setState(() => _saved = saved);
    } catch (_) {
      // icon simply stays as it was
    }
  }

  /// Saves the PDF INSIDE the app (private storage -> Home > Downloads).
  /// It is not written to the phone's own storage / Downloads folder.
  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _dlProgress = 0;
    });
    try {
      final existing = await DownloadStore.find(widget.originalUrl);
      if (existing != null) {
        if (mounted) setState(() => _saved = true);
        await _showSavedDialog(existing.title, already: true, offline: existing.isFile);
        return;
      }
      _snack('Downloading to App Downloads... / ऐप के Downloads में डाउनलोड हो रहा है...');
      final res = await DownloadStore.save(
        url: widget.originalUrl,
        downloadUrl: _downloadUrl(),
        title: widget.title,
        paid: !widget.allowExternalOpen,
        onProgress: (f) {
          if (!mounted) return;
          if ((f - _dlProgress).abs() >= 0.02 || f >= 1) setState(() => _dlProgress = f);
        },
      );
      if (mounted) setState(() => _saved = true);
      await _showSavedDialog(res.item.title, already: res.already, offline: res.offline);
    } on DownloadException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not download this PDF. Try again. / PDF डाउनलोड नहीं हुई। दोबारा कोशिश करें।');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _showSavedDialog(String title, {required bool already, required bool offline}) async {
    if (!mounted) return;
    final openDownloads = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(already ? '📥' : '✅', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                already ? 'Already in Downloads / पहले से डाउनलोड है' : 'PDF Downloaded / PDF डाउनलोड हो गई',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              Text(
                'Ye PDF Home Screen ke \"Downloads\" section mein save ho gayi hai (phone storage mein save nahi hui).\nयह PDF होम स्क्रीन के \"Downloads\" सेक्शन में सेव हो गई है (फ़ोन स्टोरेज में नहीं)।',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppC.text70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                offline
                    ? '⚡ Offline ready — bina internet bhi khul jayegi. / बिना इंटरनेट भी खुलेगी।'
                    : '☁️ Downloads section se seedha khol kar padh sakte hain (internet chahiye). / Downloads से सीधे खोलकर पढ़ सकते हैं (इंटरनेट चाहिए)।',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppC.text54, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('OK / ठीक है')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('📥 Open Downloads')),
        ],
      ),
    );
    if (openDownloads == true && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsScreen()));
    }
  }

  void _reload() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(widget.viewUrl));
  }

  Widget _downloadAction() {
    if (_downloading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, value: _dlProgress > 0 && _dlProgress < 1 ? _dlProgress : null),
        ),
      );
    }
    return IconButton(
      tooltip: 'Download in App / ऐप में डाउनलोड करें',
      icon: Icon(_saved ? Icons.download_done : Icons.download, color: _saved ? AppC.gold : Colors.white),
      onPressed: _download,
    );
  }

  // Small floating controls shown in landscape (the top bar is hidden there).
  Widget _landscapeControls() {
    if (!_controlsOpen) {
      return Positioned(
        top: 8,
        left: 8,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Menu',
            iconSize: 22,
            color: Colors.white,
            icon: const Icon(Icons.more_horiz),
            onPressed: () => setState(() => _controlsOpen = true),
          ),
        ),
      );
    }
    return Positioned(
      top: 8,
      left: 8,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(28),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
              if (widget.allowDownload) _downloadAction(),
              IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh), onPressed: _reload),
              if (widget.allowExternalOpen)
                IconButton(
                  tooltip: 'Open outside the app',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => openExternalLink(context, widget.originalUrl),
                ),
              IconButton(tooltip: 'Hide menu', icon: const Icon(Icons.close), onPressed: () => setState(() => _controlsOpen = false)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    _applyOrientation(landscape);
    return Scaffold(
      backgroundColor: AppC.bg,
      appBar: landscape
          ? null
          : AppBar(
              title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                if (widget.allowDownload) _downloadAction(),
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
          if (landscape) _landscapeControls(),
          if (_progress < 100 && !_failed)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3, color: AppC.accent, backgroundColor: Colors.transparent),
            ),
          if (_failed)
            Positioned.fill(
              child: Container(
                color: AppC.bg,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf, color: AppC.text38, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load this PDF. Check your internet connection and try again. / PDF लोड नहीं हुई। इंटरनेट जाँचकर दोबारा कोशिश करें।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppC.text54),
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
