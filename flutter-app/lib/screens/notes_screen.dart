import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/notes_store.dart';
import '../services/share_service.dart';
import '../widgets/state_views.dart';

/// Quick Notes: formulas, tricks, ya koi bhi baat likh kar rakho. Search, pin
/// aur share bhi hai. Notes sirf phone me hain (aur Cloud Backup me jaate hain).
/// Firestore ko 0 reads / 0 writes.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteItem>? _notes;
  String _q = '';

  @override
  void initState() {
    super.initState();
    NotesStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    NotesStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await NotesStore.all();
    if (!mounted) return;
    setState(() => _notes = list);
  }

  Future<void> _open([NoteItem? note]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)));
    if (mounted) _load();
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final all = _notes;
    return Scaffold(
      appBar: AppBar(title: const Text('My Notes / मेरे नोट्स')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppC.gold,
        foregroundColor: AppC.onGold,
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('New note / नया नोट'),
      ),
      body: all == null ? const LoadingView() : _content(all),
    );
  }

  Widget _content(List<NoteItem> all) {
    if (all.isEmpty) {
      return const EmptyView('No notes yet. Tap "New note" to write one.\nअभी कोई नोट नहीं। "नया नोट" दबाकर लिखें।');
    }
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all.where((n) => n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            style: TextStyle(color: AppC.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search notes / नोट्स खोजें',
              hintStyle: TextStyle(color: AppC.text38),
              prefixIcon: Icon(Icons.search, color: AppC.text54),
              filled: true,
              fillColor: AppC.card,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const EmptyView('No matching notes.\nकोई नोट नहीं मिला।')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _card(shown[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(NoteItem n) {
    final title = n.title.isEmpty ? (n.body.isEmpty ? 'Untitled' : n.body.split('\n').first) : n.title;
    return GestureDetector(
      onTap: () => _open(n),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: n.pinned ? AppC.accent.withOpacity(0.7) : AppC.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (n.pinned) const Padding(padding: EdgeInsets.only(right: 6), child: Text('📌', style: TextStyle(fontSize: 14))),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14.5)),
                ),
              ],
            ),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.3)),
            ],
            const SizedBox(height: 6),
            Text(_date(n.updatedMs), style: TextStyle(color: AppC.text38, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

/// Ek note likhne / badalne ki screen. Peeche jaane par apne aap save hota hai.
class NoteEditScreen extends StatefulWidget {
  final NoteItem? note;
  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final String _id;
  late bool _pinned;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _id = n?.id ?? NotesStore.newId();
    _title = TextEditingController(text: n?.title ?? '');
    _body = TextEditingController(text: n?.body ?? '');
    _pinned = n?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _empty => _title.text.trim().isEmpty && _body.text.trim().isEmpty;

  Future<void> _saveAndClose() async {
    if (!_deleted && !_empty) {
      final ok = await NotesStore.save(NoteItem(
        id: _id,
        title: _title.text,
        body: _body.text,
        pinned: _pinned,
        updatedMs: 0,
      ));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes limit (200) reached. Delete an old note first. / नोट्स की सीमा (200) पूरी।')),
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note? / नोट हटाएँ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete / हटाएँ')),
        ],
      ),
    );
    if (yes != true) return;
    _deleted = true;
    if (widget.note != null) await NotesStore.delete(_id);
    if (mounted) Navigator.of(context).pop();
  }

  void _share() {
    if (_empty) return;
    final t = _title.text.trim().isEmpty ? 'My note' : _title.text.trim();
    ShareService.custom(context, '📝 $t', _body.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New note / नया नोट' : 'Edit note / नोट बदलें'),
          actions: [
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            IconButton(tooltip: 'Share', icon: const Icon(Icons.share), onPressed: _share),
            if (widget.note != null) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _title,
                maxLength: NotesStore.maxTitle,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Title / शीर्षक',
                  hintStyle: TextStyle(color: AppC.text38),
                  counterText: '',
                  filled: true,
                  fillColor: AppC.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _body,
                  maxLength: NotesStore.maxBody,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: AppC.text, fontSize: 14.5, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'Write here... / यहाँ लिखें...',
                    hintStyle: TextStyle(color: AppC.text38),
                    filled: true,
                    fillColor: AppC.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
