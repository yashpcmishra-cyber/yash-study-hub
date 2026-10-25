import 'dart:math';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/flashcard_data.dart';
import '../services/flashcard_store.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';

/// Flashcards: tap karke palto, "Got it" se yaad kiya hua mark karo.
/// Cards app ke andar hain (offline chalte hain), yaad kiye hue cards phone me
/// save rehte hain - Firestore ko 0 reads / 0 writes.
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  String _cat = 'all';
  bool _onlyNew = true;
  bool _flipped = false;
  bool _loading = true;
  Set<String> _known = <String>{};
  List<Flashcard> _deck = <Flashcard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final k = await FlashcardStore.known();
      if (!mounted) return;
      _known = k;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _buildDeck();
      _loading = false;
    });
  }

  void _buildDeck() {
    final base = kFlashcards.where((c) => _cat == 'all' || c.cat == _cat).toList();
    final list = _onlyNew ? base.where((c) => !_known.contains(c.id)).toList() : base;
    list.shuffle(Random(StudyStore.today().hashCode ^ _cat.hashCode ^ (_onlyNew ? 1 : 2)));
    _deck = list;
    _flipped = false;
  }

  void _selectCat(String cat) {
    setState(() {
      _cat = cat;
      _buildDeck();
    });
  }

  void _toggleOnlyNew(bool v) {
    setState(() {
      _onlyNew = v;
      _buildDeck();
    });
  }

  Future<void> _got() async {
    if (_deck.isEmpty) return;
    final card = _deck.first;
    setState(() {
      _known = {..._known, card.id};
      _deck = List<Flashcard>.from(_deck);
      _deck.removeAt(0);
      if (!_onlyNew) _deck.add(card);
      _flipped = false;
    });
    await FlashcardStore.setKnown(card.id, true);
  }

  void _again() {
    if (_deck.length < 2) {
      setState(() => _flipped = false);
      return;
    }
    setState(() {
      final d = List<Flashcard>.from(_deck);
      final first = d.removeAt(0);
      d.add(first);
      _deck = d;
      _flipped = false;
    });
  }

  Future<void> _resetCategory() async {
    await FlashcardStore.reset(cat: _cat == 'all' ? null : _cat);
    await _load();
  }

  int _countIn(String cat, {required bool knownOnly}) {
    return kFlashcards.where((c) => (cat == 'all' || c.cat == cat) && (!knownOnly || _known.contains(c.id))).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _chips(),
                const SizedBox(height: 12),
                _progress(),
                const SizedBox(height: 12),
                if (_deck.isEmpty) _emptyDeck() else ..._deckView(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text('Show only new cards / सिर्फ़ नए कार्ड दिखाएँ', style: TextStyle(color: AppC.text70, fontSize: 12.5)),
                    ),
                    Switch(value: _onlyNew, activeColor: AppC.accent, onChanged: _toggleOnlyNew),
                  ],
                ),
                Text(
                  'Tap the card to flip. Swipe right = Got it, swipe left = Again.\nकार्ड पर टैप करके पलटें। दाएँ स्वाइप = याद है, बाएँ स्वाइप = फिर दिखाओ।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
    );
  }

  Widget _chips() {
    final cats = ['all', ...kFlashCats.keys];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(c),
            ),
        ],
      ),
    );
  }

  Widget _chip(String cat) {
    final on = _cat == cat;
    final String label;
    if (cat == 'all') {
      label = '🗂️ All / सभी';
    } else {
      final info = kFlashCats[cat]!;
      label = '${info[2]} ${info[0]}';
    }
    final k = _countIn(cat, knownOnly: true);
    final t = _countIn(cat, knownOnly: false);
    return GestureDetector(
      onTap: () => _selectCat(cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppC.gold : AppC.cardA60,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label  $k/$t',
          style: TextStyle(color: on ? AppC.onGold : AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _progress() {
    final k = _countIn(_cat, knownOnly: true);
    final t = _countIn(_cat, knownOnly: false);
    final ratio = t == 0 ? 0.0 : (k / t).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Learned / याद: $k of $t', style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 13))),
              Text('Left in deck / बाकी: ${_deck.length}', style: TextStyle(color: AppC.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: AppC.card, color: AppC.green),
          ),
        ],
      ),
    );
  }

  List<Widget> _deckView() {
    final card = _deck.first;
    return [
      GestureDetector(
        onTap: () => setState(() => _flipped = !_flipped),
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 300) {
            _got();
          } else if (v < -300) {
            _again();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim), child: child),
          ),
          child: _face(card, _flipped, key: ValueKey<String>('${card.id}_$_flipped')),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.refresh),
              label: const Text('Again / फिर दिखाओ'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _got,
              icon: const Icon(Icons.check),
              label: const Text('Got it / याद है'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _face(Flashcard c, bool back, {Key? key}) {
    final info = kFlashCats[c.cat];
    final catLabel = info == null ? '' : '${info[2]} ${info[0]} / ${info[1]}';
    final mainText = back ? c.a : c.q;
    final hiText = back ? c.ah : c.qh;
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: back ? AppC.goldWash : AppC.card2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: back ? AppC.green : AppC.accent, width: 1.4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(catLabel, style: TextStyle(color: AppC.muted, fontSize: 11.5)),
          const SizedBox(height: 6),
          Text(
            back ? 'ANSWER / उत्तर' : 'QUESTION / प्रश्न',
            style: TextStyle(color: back ? AppC.green : AppC.accent, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(mainText, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 18, height: 1.35)),
          const SizedBox(height: 8),
          Text(hiText, style: TextStyle(color: AppC.text70, fontSize: 16, height: 1.35)),
          const SizedBox(height: 14),
          Center(child: Text(back ? '' : 'Tap to see the answer / उत्तर देखने के लिए टैप करें', style: TextStyle(color: AppC.text38, fontSize: 11.5))),
        ],
      ),
    );
  }

  Widget _emptyDeck() {
    final noCards = _countIn(_cat, knownOnly: false) == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 42)),
          const SizedBox(height: 8),
          Text(
            noCards ? 'No cards here.\nयहाँ कोई कार्ड नहीं है।' : 'You learned every card here!\nआपने यहाँ के सारे कार्ड याद कर लिए!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (!noCards)
            ElevatedButton.icon(
              onPressed: _resetCategory,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Start again / फिर से शुरू करें'),
            ),
        ],
      ),
    );
  }
}
