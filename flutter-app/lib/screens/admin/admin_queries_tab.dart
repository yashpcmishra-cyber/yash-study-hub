import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/query_model.dart';
import '../../services/queries_service.dart';
import '../../widgets/depth_card.dart';
import '../../widgets/state_views.dart';

/// Admin Panel -> "Queries" tab: see student doubts and reply.
class AdminQueriesTab extends StatefulWidget {
  const AdminQueriesTab({super.key});
  @override
  State<AdminQueriesTab> createState() => _AdminQueriesTabState();
}

class _AdminQueriesTabState extends State<AdminQueriesTab> with AutomaticKeepAliveClientMixin {
  final _svc = QueriesService();
  late final Stream<List<QueryModel>> _stream = _svc.streamAll();
  String _filter = 'pending'; // 'pending' | 'answered' | 'all'

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<QueryModel>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView();
        final all = snap.data!;
        final pendingCount = all.where((q) => !q.answered).length;
        final shown = all.where((q) {
          if (_filter == 'pending') return !q.answered;
          if (_filter == 'answered') return q.answered;
          return true;
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Wrap(
              spacing: 8,
              children: [
                _chip('pending', 'Pending ($pendingCount)'),
                _chip('answered', 'Answered'),
                _chip('all', 'All'),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Doubts $kQueryRetentionDays din baad Firebase se apne aap delete ho jaate hain.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            if (shown.isEmpty)
              const SizedBox(height: 160, child: EmptyView('Koi doubt nahi.'))
            else
              ...shown.map((q) => _QueryCard(key: ValueKey(q.id), q: q, svc: _svc)),
          ],
        );
      },
    );
  }

  Widget _chip(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      );
}

/// One doubt with its own reply box (own widget so the text controller is
/// disposed together with the card).
class _QueryCard extends StatefulWidget {
  final QueryModel q;
  final QueriesService svc;
  const _QueryCard({super.key, required this.q, required this.svc});

  @override
  State<_QueryCard> createState() => _QueryCardState();
}

class _QueryCardState extends State<_QueryCard> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.q.reply);
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _sendReply() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      _snack('Pehle reply likho.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.svc.reply(widget.q.id, text);
      if (mounted) setState(() => _editing = false);
      _snack('Reply bhej diya ✅');
    } catch (e) {
      _snack('Reply nahi gaya: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Doubt delete karein?'),
        content: const Text('Ye doubt aur uska reply hamesha ke liye hat jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.delete(widget.q.id);
    } catch (e) {
      _snack('Delete nahi hua: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final who = q.studentName.isNotEmpty ? q.studentName : 'Student';
    final showBox = !q.answered || _editing;
    return DepthCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(who, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('${q.studentEmail} \u2022 ${DateFormat('d MMM, h:mm a').format(q.when)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: _delete),
              ],
            ),
            const SizedBox(height: 6),
            Text(q.text, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
            const SizedBox(height: 10),
            if (showBox) ...[
              TextField(
                controller: _ctrl,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                enabled: !_busy,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Reply likho...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF050B24),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editing)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _editing = false;
                                _ctrl.text = q.reply;
                              }),
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _busy ? null : _sendReply,
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(q.answered ? 'Update reply' : 'Reply bhejo'),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFF29).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(q.reply, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _editing = true), child: const Text('Edit reply')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
