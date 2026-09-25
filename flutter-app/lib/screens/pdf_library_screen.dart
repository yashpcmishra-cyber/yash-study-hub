import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';
import 'pdf_folder_screen.dart';

class PdfLibraryScreen extends StatelessWidget {
  const PdfLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Library'),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFFFF29),
            labelColor: Color(0xFFFFFF29),
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'Free'), Tab(text: 'Paid Batch')],
          ),
        ),
        body: const TabBarView(children: [_FreeFoldersTab(), _BatchFoldersTab()]),
      ),
    );
  }
}

class _FreeFoldersTab extends StatefulWidget {
  const _FreeFoldersTab();

  @override
  State<_FreeFoldersTab> createState() => _FreeFoldersTabState();
}

class _FreeFoldersTabState extends State<_FreeFoldersTab> {
  final _fs = FirestoreService();
  late Stream<List<PdfFolderModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamFolders(type: 'free');
  }

  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamFolders(type: 'free'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PdfFolderModel>>(
      stream: _stream,
      builder: (context, snap) {
        Widget content;
        if (snap.hasError) {
          content = PullableMessage(child: ErrorView(error: snap.error));
        } else if (!snap.hasData) {
          content = const PullableMessage(child: LoadingView());
        } else if (snap.data!.isEmpty) {
          content = const PullableMessage(child: EmptyView('No free folders yet.'));
        } else {
          final folders = snap.data!;
          content = ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: folders.length,
            itemBuilder: (context, i) {
              final f = folders[i];
              return DepthCard(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfFolderScreen(folder: f))),
                child: ListTile(
                  leading: const Text('📁', style: TextStyle(fontSize: 22)),
                  title: Text(f.name, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              );
            },
          );
        }
        return RefreshIndicator(onRefresh: _refresh, child: content);
      },
    );
  }
}

class _BatchFoldersTab extends StatefulWidget {
  const _BatchFoldersTab();

  @override
  State<_BatchFoldersTab> createState() => _BatchFoldersTabState();
}

class _BatchFoldersTabState extends State<_BatchFoldersTab> {
  final _fs = FirestoreService();
  late Stream<List<BatchModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamBatches();
  }

  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamBatches());
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Opens a batch folder only if this phone's saved email + code have been
  // approved for that batch. Never throws (offline => friendly message).
  Future<void> _openFolder(BatchModel b, PdfFolderModel f) async {
    bool ok = false;
    bool expired = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('student_email');
      final code = prefs.getString('access_code_${b.id}') ?? '';
      if (email != null && email.trim().isNotEmpty) {
        final res = await _fs.checkAccess(email, b.id, code);
        ok = res.granted;
        expired = res.expired;
      }
    } catch (_) {
      _snack("Couldn't verify your access. Check your internet connection and try again.");
      return;
    }
    if (!mounted) return;
    if (!ok) {
      _snack(expired
          ? 'Your access to this batch has expired \u2014 renew it under Paid Batches. / Access khatam ho gaya \u2014 Paid Batches mein renew karo.'
          : 'This batch is locked \u2014 unlock it first (under Paid Batches).');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfFolderScreen(folder: f)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BatchModel>>(
      stream: _stream,
      builder: (context, snap) {
        Widget content;
        if (snap.hasError) {
          content = PullableMessage(child: ErrorView(error: snap.error));
        } else if (!snap.hasData) {
          content = const PullableMessage(child: LoadingView());
        } else if (snap.data!.isEmpty) {
          content = const PullableMessage(child: EmptyView('No batch found'));
        } else {
          final batches = snap.data!;
          content = ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: batches.length,
            itemBuilder: (context, i) {
              final b = batches[i];
              return DepthCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  iconColor: const Color(0xFFFFFF29),
                  collapsedIconColor: Colors.grey,
                  leading: NetImage(url: b.iconUrl, width: 36, height: 36, fallbackIcon: '🎓', radius: 8),
                  title: Text(b.title, style: const TextStyle(color: Colors.white)),
                  children: [
                    StreamBuilder<List<PdfFolderModel>>(
                      stream: _fs.streamFolders(type: 'batch', batchId: b.id),
                      builder: (context, fsnap) {
                        if (fsnap.hasError) {
                          return const Padding(padding: EdgeInsets.all(12), child: Text("Couldn't load folders.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                        }
                        if (!fsnap.hasData) {
                          return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                        }
                        final folders = fsnap.data!;
                        if (folders.isEmpty) {
                          return const Padding(padding: EdgeInsets.all(12), child: Text('No folder in this batch yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
                        }
                        return Column(
                          children: folders
                              .map((f) => ListTile(
                                    leading: const Text('📁', style: TextStyle(fontSize: 18)),
                                    title: Text(f.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    onTap: () => _openFolder(b, f),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        }
        return RefreshIndicator(onRefresh: _refresh, child: content);
      },
    );
  }
}
