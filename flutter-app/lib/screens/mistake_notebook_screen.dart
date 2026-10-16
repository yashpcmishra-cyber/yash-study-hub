import 'package:flutter/material.dart';
import '../services/mock_rank_service.dart';
import '../services/study_store.dart';
import '../widgets/di_image.dart';
import '../widgets/state_views.dart';
import 'quiz_session_screen.dart';

import '../app_colors.dart';

/// Mistake Notebook: galat kiye sawal (apne aap judte hain) + Saved (bookmark)
/// sawal. Sab kuch sirf is phone me rehta hai, 30 din baad apne aap hat jaata hai.
class MistakeNotebookScreen extends StatefulWidget {
  /// 0 = Galtiyan, 1 = Saved
  final int initialTab;
  const MistakeNotebookScreen({super.key, this.initialTab = 0});

  @override
  State<MistakeNotebookScreen> createState() => _MistakeNotebookScreenState();
}

class _MistakeNotebookScreenState extends State<MistakeNotebookScreen> {
  List<SavedQuestion> _mistakes = const [];
  List<SavedQuestion> _saved = const [];
  bool _loading = true;
  bool _hindi = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await StudyStore.mistakes();
    final s = await StudyStore.bookmarks();
    if (!mounted) return;
    setState(() {
      _mistakes = m;
      _saved = s;
      _loading = false;
    });
  }

  bool get _hasHindi => [..._mistakes, ..._saved].any((e) => e.question.textHi.trim().isNotEmpty);

  Future<void> _practice(List<SavedQuestion> all, {required bool fromMistakes}) async {
    final items = all.take(10).toList();
    if (items.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: fromMistakes ? 'Practice: Mistakes / गलतियाँ' : 'Practice: Saved',
        questions: items.map((e) => e.question).toList(),
        bookmarkSource: 'Practice',
        onFinished: (answers) => StudyStore.recordPractice(
          items: items,
          answers: answers,
          removeCorrectFromMistakes: fromMistakes,
        ),
      ),
    ));
    _load();
  }

  Future<void> _remove(SavedQuestion e, {required bool fromMistakes}) async {
    if (fromMistakes) {
      await StudyStore.removeMistake(e.key);
    } else {
      await StudyStore.removeBookmark(e.key);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1).toInt(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mistake Notebook'),
          actions: [
            if (_hasHindi)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _langBtn('EN', !_hindi, () => setState(() => _hindi = false)),
                    _langBtn('हिं', _hindi, () => setState(() => _hindi = true)),
                  ]),
                ),
              ),
          ],
          bottom: TabBar(
            indicatorColor: const Color(0xFFFFFF29),
            labelColor: const Color(0xFFFFFF29),
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: '❌ Mistakes / गलतियाँ (${_mistakes.length})'),
              Tab(text: '⭐ Saved / सेव (${_saved.length})'),
            ],
          ),
        ),
        body: _loading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _list(_mistakes, fromMistakes: true),
                  _list(_saved, fromMistakes: false),
                ],
              ),
      ),
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

  Widget _list(List<SavedQuestion> items, {required bool fromMistakes}) {
    if (items.isEmpty) {
      return EmptyView(
        fromMistakes
            ? 'No mistakes yet 🎉\nWrong questions from Mock Tests or Daily Quiz will appear here automatically.\n\nअभी कोई गलती नहीं 🎉\nMock Test या Daily Quiz में गलत हुए सवाल अपने आप यहाँ आ जाएँगे।'
            : 'Nothing saved yet.\nTap 🔖 on any question to save it here.\n\nअभी कुछ सेव नहीं है।\nकिसी भी सवाल पर 🔖 दबाएँ, वह यहाँ सेव हो जाएगा।',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ElevatedButton.icon(
          onPressed: () => _practice(items, fromMistakes: fromMistakes),
          icon: const Icon(Icons.play_arrow),
          label: Text('Practice ${items.length > 10 ? "10" : items.length} questions / सवाल'),
        ),
        const SizedBox(height: 6),
        Text(
          fromMistakes
              ? 'Questions you answer correctly in practice are removed from the notebook. Entries older than 30 days are removed automatically.\nप्रैक्टिस में सही किए सवाल नोटबुक से हट जाते हैं। 30 दिन पुरानी एंट्रियाँ अपने आप हट जाती हैं।'
              : 'Entries older than 30 days are removed automatically.\n30 दिन पुरानी एंट्रियाँ अपने आप हट जाती हैं।',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppC.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        for (final e in items) _card(e, fromMistakes: fromMistakes),
      ],
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t).inDays;
    if (d <= 0) return 'today / आज';
    if (d == 1) return 'yesterday / कल';
    return '$d days ago / $d दिन पहले';
  }

  Widget _card(SavedQuestion e, {required bool fromMistakes}) {
    final q = e.question;
    final opts = mockOptions(q, _hindi);
    final explanation = mockExplanation(q, _hindi).trim();
    final passage = mockPassage(q, _hindi);
    final passageImg = q.passageImage.trim();
    final tag = [if (e.source.isNotEmpty) e.source, _ago(e.savedAt)].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.muted, fontSize: 11))),
            InkWell(
              onTap: () => _remove(e, fromMistakes: fromMistakes),
              child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, color: AppC.text54, size: 20)),
            ),
          ]),
          if (passage.isNotEmpty || passageImg.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6, bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.text12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (passage.isNotEmpty) Text(passage, style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.4)),
                  if (passageImg.isNotEmpty) Padding(padding: EdgeInsets.only(top: passage.isNotEmpty ? 8 : 0), child: DiImage(url: passageImg)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(mockText(q, _hindi), style: TextStyle(color: AppC.text, fontSize: 14, height: 1.35)),
          const SizedBox(height: 8),
          for (var oi = 0; oi < opts.length; oi++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: oi == q.correctIndex ? AppC.green : AppC.text12),
              ),
              child: Text(
                '${String.fromCharCode(65 + oi)}. ${opts[oi]}${oi == q.correctIndex ? '  ✓' : ''}',
                style: TextStyle(color: oi == q.correctIndex ? AppC.green : AppC.text70, fontSize: 13),
              ),
            ),
          if (explanation.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explanation', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(explanation, style: TextStyle(color: AppC.text, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
