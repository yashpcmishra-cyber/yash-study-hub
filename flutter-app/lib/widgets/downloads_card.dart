import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../screens/downloads_screen.dart';
import '../services/download_store.dart';

/// Home ka "Downloads / मेरे डाउनलोड्स" card (Web ki Home screen jaisa).
/// Subtitle me kitni PDFs App me save hain wo dikhta hai. Sab data phone me
/// hai - Firestore se kuch nahi padhta / likhta.
class DownloadsHomeCard extends StatefulWidget {
  /// Downloads khali ho to "PDF Library" button isi se tab badalta hai.
  final VoidCallback? onOpenLibrary;
  const DownloadsHomeCard({super.key, this.onOpenLibrary});

  @override
  State<DownloadsHomeCard> createState() => _DownloadsHomeCardState();
}

class _DownloadsHomeCardState extends State<DownloadsHomeCard> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    DownloadStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    DownloadStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final n = await DownloadStore.count();
      if (!mounted) return;
      if (n != _count) setState(() => _count = n);
    } catch (_) {
      // purani ginti dikhti rahegi
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DownloadsScreen(onOpenLibrary: widget.onOpenLibrary)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final sub = _count > 0
        ? '$_count ${_count == 1 ? 'PDF' : 'PDFs'} saved in App • Tap to open / खोलने के लिए टैप करें'
        : 'App mein download ki gayi PDFs yahan milengi / डाउनलोड की गई PDFs यहाँ मिलेंगी';
    return Material(
      color: AppC.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppC.accent, width: 1.5),
      ),
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppC.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('📥', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Downloads / मेरे डाउनलोड्स',
                      style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(sub, style: TextStyle(color: AppC.text54, fontSize: 12.5, height: 1.35)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppC.muted),
            ],
          ),
        ),
      ),
    );
  }
}
