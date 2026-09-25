import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';
import 'batch_detail_screen.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  final _fs = FirestoreService();
  late Stream<List<BatchModel>> _stream;
  // Which batches THIS phone's saved email already has granted access to —
  // only used to show the "Unlocked" badge below; unlocking itself still
  // works exactly as before, inside BatchDetailScreen.
  String _email = '';
  Set<String> _granted = const <String>{};
  String _grantedCheckedFor = ''; // email + batch ids already checked, so we don't re-check on every rebuild

  @override
  void initState() {
    super.initState();
    _stream = _fs.streamBatches();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = (prefs.getString('student_email') ?? '').trim();
      if (email.isNotEmpty && mounted) setState(() => _email = email);
    } catch (_) {
      // No saved email yet, or prefs unavailable — list just shows with no badges.
    }
  }

  Future<void> _refreshGranted(List<BatchModel> batches) async {
    if (_email.isEmpty || batches.isEmpty) return;
    final key = '$_email|${batches.map((b) => b.id).join(',')}';
    if (key == _grantedCheckedFor) return;
    _grantedCheckedFor = key;
    final ids = await _fs.grantedBatchIds(_email, batches.map((b) => b.id).toList());
    if (mounted) setState(() => _granted = ids);
  }

  Future<void> _refresh() async {
    setState(() {
      _stream = _fs.streamBatches();
      _grantedCheckedFor = ''; // force a re-check
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paid Batches')),
      body: StreamBuilder<List<BatchModel>>(
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
            // Granted batches first (stable order within each group), so
            // a student instantly sees what they already own at the top.
            final all = snap.data!;
            WidgetsBinding.instance.addPostFrameCallback((_) => _refreshGranted(all));
            final granted = _granted;
            final batches = [
              ...all.where((b) => granted.contains(b.id)),
              ...all.where((b) => !granted.contains(b.id)),
            ];
            content = ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: batches.length,
              itemBuilder: (context, i) {
                final b = batches[i];
                final isGranted = granted.contains(b.id);
                final card = DepthCard(
                  margin: isGranted ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
                  onTap: () async {
                    // Awaited so we can refresh below when the student comes
                    // back — e.g. after they save their email / get granted
                    // access inside BatchDetailScreen. Without this, the
                    // "Unlocked" badge would only ever pick up an email that
                    // was already saved BEFORE this screen first loaded.
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batch: b)));
                    if (mounted) {
                      await _loadEmail();
                      _grantedCheckedFor = ''; // force a re-check — access may have just been granted
                      _refreshGranted(all);
                    }
                  },
                  child: ListTile(
                    leading: NetImage(url: b.iconUrl, width: 44, height: 44, fallbackIcon: '🎓', radius: 10),
                    title: Text(b.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${b.videos} videos \u2022 ${b.pdfs} PDFs${b.hasValidity ? ' \u2022 ${b.validityLabel}' : ''}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    trailing: isGranted
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('✅', style: TextStyle(fontSize: 15)),
                              SizedBox(width: 4),
                              Text('Unlocked', style: TextStyle(color: Colors.green, fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : Text('\u20b9${b.price}', style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold)),
                  ),
                );
                if (!isGranted) return card;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: card,
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
