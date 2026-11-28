import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../services/download_store.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import 'downloaded_pdf_viewer_screen.dart';
import 'pdf_viewer_screen.dart';

/// "Downloads / मेरे डाउनलोड्स" - App me download ki gayi PDFs (Web jaisa).
/// Ye PDFs sirf App ke private folder me hain, phone storage me nahi.
///
/// [onOpenLibrary]: Home se khulne par "PDF Library" button ke liye (nahi diya
/// to button nahi dikhta).
class DownloadsScreen extends StatefulWidget {
  final VoidCallback? onOpenLibrary;
  const DownloadsScreen({super.key, this.onOpenLibrary});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadItem>? _items;
  Object? _error;
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    DownloadStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DownloadStore.changes.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await DownloadStore.all();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(DownloadItem it) async {
    if (it.isFile) {
      await openDownloadedPdf(context, it);
    } else {
      // Sirf link save hui thi (Drive ne asli file nahi di) -> online viewer.
      await openPdfInApp(
        context,
        link: it.url,
        title: it.title,
        allowExternalOpen: !it.paid,
        allowDownload: false,
      );
    }
  }

  Future<void> _remove(DownloadItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Remove PDF? / PDF हटाएँ?', style: TextStyle(color: AppC.text, fontSize: 17)),
        content: Text(
          'Remove "${it.title}" from Downloads?\nक्या इस PDF को Downloads से हटाएँ?',
          style: TextStyle(color: AppC.text70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove / हटाएँ', style: TextStyle(color: AppC.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DownloadStore.remove(it.id);
      _snack('Removed from Downloads / हटा दिया गया');
    } catch (_) {
      _snack('Could not remove. Try again. / हटा नहीं सके। दोबारा कोशिश करें।');
    }
  }

  String _dateText(int ms) {
    if (ms <= 0) return '';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));
    } catch (_) {
      return '';
    }
  }

  Widget _emptyCard() {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppC.line),
      ),
      child: Column(
        children: [
          const Text('📥', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text('Abhi koi PDF download nahi ki hai', textAlign: TextAlign.center, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            'Kisi bhi PDF ko khol kar upar Download (⬇) icon dabaiye — wo yahan App mein save ho jayegi.\nकिसी भी PDF में ऊपर Download (⬇) दबाएँ — वह यहीं सेव हो जाएगी।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text54, fontSize: 13, height: 1.4),
          ),
          if (widget.onOpenLibrary != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenLibrary?.call();
              },
              child: const Text('📚 Open PDF Library'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(DownloadItem it) {
    final date = _dateText(it.savedMs);
    final sizeText = formatBytes(it.size);
    final tagText = it.isFile ? '⚡ Offline Ready${sizeText.isEmpty ? '' : ' · $sizeText'}' : '☁️ Saved link (online)';
    return DepthCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _open(it),
      child: ListTile(
        leading: const Text('📄', style: TextStyle(fontSize: 26)),
        title: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600)),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: tagText, style: TextStyle(color: it.isFile ? AppC.green : AppC.text54, fontWeight: it.isFile ? FontWeight.w600 : FontWeight.normal)),
              if (it.paid) TextSpan(text: ' · 🔒 Batch', style: TextStyle(color: AppC.text54)),
              if (date.isNotEmpty) TextSpan(text: ' · $date', style: TextStyle(color: AppC.text54)),
            ],
          ),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: 'Remove / हटाएँ',
          icon: Icon(Icons.delete_outline, color: AppC.text54),
          onPressed: () => _remove(it),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null && _items == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load Downloads. / Downloads लोड नहीं हो सके।', textAlign: TextAlign.center, style: TextStyle(color: AppC.text54)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final items = _items;
    if (items == null) return const LoadingView();

    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? items : items.where((e) => e.title.toLowerCase().contains(q)).toList();
    var totalBytes = 0;
    for (final it in items) {
      totalBytes += it.size;
    }
    final summary = '${items.length} ${items.length == 1 ? 'PDF' : 'PDFs'} saved${totalBytes > 0 ? ' • ${formatBytes(totalBytes)} stored offline' : ''}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          if (items.isEmpty)
            _emptyCard()
          else ...[
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: AppC.text),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppC.card,
                hintText: 'Search downloaded PDFs / डाउनलोड की गई PDF खोजें',
                hintStyle: TextStyle(color: AppC.text38, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: AppC.text54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppC.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppC.line)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
              child: Text(summary, style: TextStyle(color: AppC.text54, fontSize: 12)),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No match / कोई PDF नहीं मिली', textAlign: TextAlign.center, style: TextStyle(color: AppC.text54)),
              )
            else
              ...shown.map(_row),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Ye PDFs sirf is App ke Downloads section mein save rehti hain (phone ki Gallery / File Manager mein nahi dikhengi). App uninstall karne ya Clear data karne par ye hat jayengi.\nये PDFs केवल ऐप के Downloads सेक्शन में सेव रहती हैं (फ़ोन स्टोरेज/फ़ाइल मैनेजर में नहीं)।',
              style: TextStyle(color: AppC.text38, fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads / मेरे डाउनलोड्स')),
      body: _body(),
    );
  }
}
