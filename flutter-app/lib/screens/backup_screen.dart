import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/backup_service.dart';
import '../widgets/state_views.dart';

/// Cloud Backup: streak, mistakes, flashcards, notes ... ka data apne account
/// me save karo aur naye phone / reinstall ke baad wapas lao.
/// Sirf button dabane par 1 read ya 1 write hota hai.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _loadFailed = false;
  BackupInfo? _info;

  bool get _loggedIn => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    if (!_loggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final i = await BackupService.fetchInfo();
      if (!mounted) return;
      setState(() {
        _info = i;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    final r = await BackupService.backupNow();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(r.message);
    if (r.ok) _loadInfo();
  }

  Future<void> _restore() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup? / बैकअप वापस लाएँ?'),
        content: const Text(
          'Your current progress on this phone will be replaced by the saved backup.\n\n'
          'इस फ़ोन की मौजूदा प्रोग्रेस सेव किए हुए बैकअप से बदल जाएगी।',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore / वापस लाएँ')),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _busy = true);
    final r = await BackupService.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(r.message);
  }

  String _when(DateTime? d) {
    if (d == null) return 'Saved earlier / पहले सेव किया था';
    final l = d.toLocal();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final ap = l.hour >= 12 ? 'PM' : 'AM';
    return '${l.day} ${m[l.month - 1]} ${l.year}, $h:${l.minute.toString().padLeft(2, '0')} $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Backup / क्लाउड बैकअप')),
      body: _loading ? const LoadingView() : _content(),
    );
  }

  Widget _content() {
    if (!_loggedIn) {
      return const EmptyView('Please log in to use Cloud Backup.\nक्लाउड बैकअप के लिए लॉगिन करें।');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppC.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('☁️ Keep your progress safe', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('अपनी प्रोग्रेस सुरक्षित रखें', style: TextStyle(color: AppC.text70, fontSize: 13)),
              const SizedBox(height: 10),
              Text(
                'Streak, mistakes, bookmarks, flashcards, revision, study time, syllabus, speed maths and notes are saved on this phone. '
                'Back them up here so a new phone or reinstall never wipes them.\n\n'
                'स्ट्रीक, गलतियाँ, बुकमार्क, फ़्लैशकार्ड, रिवीज़न, स्टडी टाइम, सिलेबस, स्पीड मैथ्स और नोट्स इसी फ़ोन में सेव रहते हैं। '
                'यहाँ बैकअप रखें ताकि नया फ़ोन या रीइंस्टॉल करने पर ये न जाएँ।',
                style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Text(_info != null ? '✅' : (_loadFailed ? '⚠️' : '📭'), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _info != null ? 'Last backup / पिछला बैकअप' : (_loadFailed ? "Couldn't check / जाँच नहीं हो सकी" : 'No backup yet / अभी कोई बैकअप नहीं'),
                      style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    if (_info != null) Text(_when(_info!.at), style: TextStyle(color: AppC.text70, fontSize: 12.5)),
                    if (_loadFailed)
                      GestureDetector(
                        onTap: _loadInfo,
                        child: Text('Tap to retry / दोबारा कोशिश करें', style: TextStyle(color: AppC.accent, fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _busy ? null : _backup,
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
          label: const Text('Back up now / अभी बैकअप लें'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: (_busy || _info == null) ? null : _restore,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppC.accent,
            side: BorderSide(color: AppC.accent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Restore backup / बैकअप वापस लाएँ'),
        ),
        const SizedBox(height: 14),
        Text(
          'Each backup replaces your previous one. It is stored only in your own account.\nहर नया बैकअप पिछले को बदल देता है। यह सिर्फ़ आपके अकाउंट में रहता है।',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
        ),
      ],
    );
  }
}
