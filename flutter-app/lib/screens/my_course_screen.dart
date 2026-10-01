import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';
import 'batch_detail_screen.dart';

/// "My Course" — only the paid batches this student's account currently has
/// VALID access to (granted + not expired). Uses the same check as the
/// "Unlocked" badge in Paid Batches (FirestoreService.grantedBatchIds).
class MyCourseScreen extends StatefulWidget {
  const MyCourseScreen({super.key});

  @override
  State<MyCourseScreen> createState() => _MyCourseScreenState();
}

class _MyCourseScreenState extends State<MyCourseScreen> {
  final _fs = FirestoreService();
  late Stream<List<BatchModel>> _stream;
  final String _email = (FirebaseAuth.instance.currentUser?.email ?? '').trim();

  Set<String>? _granted; // null = still checking
  String _checkedKey = ''; // email + batch ids already checked

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamBatches();
  }

  Future<void> _loadGranted(List<BatchModel> batches, {bool force = false}) async {
    if (_email.isEmpty) return;
    final key = '$_email|${batches.map((b) => b.id).join(',')}';
    if (!force && key == _checkedKey) return;
    _checkedKey = key;
    final ids = await _fs.grantedBatchIds(_email, batches.map((b) => b.id).toList());
    if (mounted) setState(() => _granted = ids);
  }

  Future<void> _refresh() async {
    setState(() {
      _stream = _fs.streamBatches();
      _checkedKey = '';
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Course')),
      body: _email.isEmpty
          ? const EmptyView('Apne courses dekhne ke liye login karein.')
          : StreamBuilder<List<BatchModel>>(
              stream: _stream,
              builder: (context, snap) {
                Widget content;
                if (snap.hasError) {
                  content = PullableMessage(child: ErrorView(error: snap.error));
                } else if (!snap.hasData) {
                  content = const PullableMessage(child: LoadingView());
                } else {
                  final all = snap.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadGranted(all));
                  final granted = _granted;
                  if (granted == null && all.isNotEmpty) {
                    content = const PullableMessage(child: LoadingView());
                  } else {
                    final mine = all.where((b) => granted?.contains(b.id) ?? false).toList();
                    if (mine.isEmpty) {
                      content = const PullableMessage(
                        child: EmptyView('Abhi koi active course nahi hai.\nPaid Batches se batch kharidein.'),
                      );
                    } else {
                      content = ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: mine.length,
                        itemBuilder: (context, i) {
                          final b = mine[i];
                          return DepthCard(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batch: b)));
                              // Access may have expired / changed meanwhile.
                              if (mounted) _loadGranted(all, force: true);
                            },
                            child: ListTile(
                              leading: NetImage(url: b.iconUrl, width: 44, height: 44, fallbackIcon: '🎓', radius: 10),
                              title: Text(b.title, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                '${b.videos} videos \u2022 ${b.pdfs} PDFs${b.hasValidity ? ' \u2022 ${b.validityLabel}' : ''}',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                              trailing: const Text('✅', style: TextStyle(fontSize: 16)),
                            ),
                          );
                        },
                      );
                    }
                  }
                }
                return RefreshIndicator(onRefresh: _refresh, child: content);
              },
            ),
    );
  }
}
