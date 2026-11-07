import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/models.dart';
import '../services/bookmark_store.dart';
import '../services/mock_rank_service.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';
import 'quiz_session_screen.dart';

/// Saved Questions: quiz / free MCQ ke dauran ⭐ se save kiye sawal.
/// Sawal par tap = jawab + explanation khulta hai. "Practice" se saved sawal
/// ka quiz chalta hai (galat wale Smart Revision me chale jaate hain).
/// Sab data phone me hai - Firestore ko 0 reads / 0 writes.
class SavedQuestionsScreen extends StatefulWidget {
  const SavedQuestionsScreen({super.key});

  @override
  State<SavedQuestionsScreen> createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  List<BookmarkItem>? _items;
  final Set<String> _open = <String>{};
  bool _hindi = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    BookmarkStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    BookmarkStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await BookmarkStore.all();
    if (!mounted) return;
    setState(() => _items = list);
  }

  bool get _hasHindi => (_items ?? const <BookmarkItem>[]).any((b) => b.question.textHi.trim().isNotEmpty);

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _remove(BookmarkItem b) async {
    await BookmarkStore.remove(b.key);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Removed / हटा दिया'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => BookmarkStore.toggle(b.question, source: b.source),
        ),
      ));
  }

  Future<void> _clearAll() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove all saved questions? / सब सेव सवाल हटाएँ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove all / सब हटाएँ')),
        ],
      ),
    );
    if (yes == true) await BookmarkStore.clearAll();
  }

  Future<void> _practice(List<BookmarkItem> items) async {
    if (items.isEmpty) return;
    final picked = List<BookmarkItem>.from(items)..shuffle();
    final qs = picked.take(20).map((e) => e.question).toList();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: 'Saved Questions / सेव सवाल',
        questions: qs,
        onFinished: (answers) => _finishPractice(qs, answers),
      ),
    ));
  }

  /// Galat sawal Smart Revision me, kiye hue sawal aaj ke goal me.
  Future<void> _finishPractice(List<MockQuestion> qs, List<int?> answers) async {
    final wrong = <MockQuestion>[];
    var answered = 0;
    for (var i = 0; i < qs.length; i++) {
      final a = i < answers.length ? answers[i] : null;
      if (a == null) continue;
      answered++;
      if (a != qs[i].correctIndex) wrong.add(qs[i]);
    }
    await StudyStore.addMistakes(wrong, subject: 'Saved Questions', source: 'Saved Questions');
    await StudyStore.addGoalProgress(answered);
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Questions / सेव सवाल'),
        actions: [
          if (all != null && all.isNotEmpty && _hasHindi)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _langBtn('EN', !_hindi, () => setState(() => _hindi = false)),
                    _langBtn('हिं', _hindi, () => setState(() => _hindi = true)),
                  ]),
                ),
              ),
            ),
          if (all != null && all.isNotEmpty)
            IconButton(tooltip: 'Remove all', icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clearAll),
        ],
      ),
      body: all == null ? const LoadingView() : _content(all),
    );
  }

  Widget _langBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: active ? AppC.gold : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: active ? AppC.onGold : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _content(List<BookmarkItem> all) {
    if (all.isEmpty) {
      return const EmptyView('No saved questions yet.\nDuring any quiz, tap the ⭐ to save a question here.\n\nअभी कोई सेव सवाल नहीं।\nक्विज़ के दौरान ⭐ दबाकर सवाल यहाँ सेव करें।');
    }
    final q = _search.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all.where((b) {
            final x = b.question;
            return x.text.toLowerCase().contains(q) || x.textHi.toLowerCase().contains(q) || b.source.toLowerCase().contains(q);
          }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(color: AppC.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search saved questions / सवाल खोजें',
              hintStyle: TextStyle(color: AppC.text38),
              prefixIcon: Icon(Icons.search, color: AppC.text54),
              filled: true,
              fillColor: AppC.card,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${all.length} saved / सेव  •  tap a question to see the answer / जवाब देखने के लिए टैप करें', style: TextStyle(color: AppC.muted, fontSize: 11)),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const EmptyView('No matching questions.\nकोई सवाल नहीं मिला।')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _card(shown[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _practice(shown.isEmpty ? all : shown),
              icon: const Icon(Icons.play_arrow),
              label: Text('Practice ${shown.length > 20 ? 20 : (shown.isEmpty ? all.length : shown.length)} random / प्रैक्टिस करें'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BookmarkItem b) {
    final q = b.question;
    final open = _open.contains(b.key);
    final opts = mockOptions(q, _hindi);
    final exp = mockExplanation(q, _hindi).trim();
    final passage = mockPassage(q, _hindi);
    final meta = b.source.isEmpty ? _date(b.savedMs) : '${b.source}  •  ${_date(b.savedMs)}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: open ? AppC.accent.withOpacity(0.7) : AppC.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (open) {
                _open.remove(b.key);
              } else {
                _open.add(b.key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            mockText(q, _hindi),
                            maxLines: open ? null : 3,
                            overflow: open ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14, height: 1.35),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text38, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove from saved',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.star, color: AppC.amber),
                    onPressed: () => _remove(b),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (passage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(10)),
                      child: Text(passage, style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.4)),
                    ),
                  for (var oi = 0; oi < opts.length; oi++) _option(oi, opts[oi], q.correctIndex),
                  if (exp.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Explanation', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(exp, style: TextStyle(color: AppC.text, fontSize: 13, height: 1.35)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _option(int oi, String text, int correct) {
    final isCorrect = oi == correct;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrect ? AppC.greenWash : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isCorrect ? AppC.green : AppC.text24),
      ),
      child: Text(
        '${String.fromCharCode(65 + oi)}. $text${isCorrect ? '  ✓' : ''}',
        style: TextStyle(color: isCorrect ? AppC.green : AppC.text, fontSize: 13.5, height: 1.3),
      ),
    );
  }
}
