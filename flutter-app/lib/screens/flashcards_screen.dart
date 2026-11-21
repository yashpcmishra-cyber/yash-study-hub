import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/flashcard_data.dart';
import '../services/flashcard_store.dart';

/// Flashcards: GK / Maths / English ke sawal-jawab ke cards. Card dabao -> jawab
/// dikhta hai. "Yaad ho gaya" dabane par card hat jata hai (2 XP), "Fir se" par
/// card baad me dobara aata hai. Sab kuch phone me - Firestore ko 0 reads / 0 writes.
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  String _cat = 'all';
  Set<String> _known = <String>{};
  List<Flashcard> _deck = <Flashcard>[];
  bool _flipped = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final k = await FlashcardStore.known();
    if (!mounted) return;
    setState(() {
      _known = k;
      _loading = false;
      _rebuildDeck();
    });
  }

  bool _inCat(Flashcard c) => _cat == 'all' || c.cat == _cat;

  void _rebuildDeck() {
    _deck = kFlashcards.where((c) => _inCat(c) && !_known.contains(c.id)).toList()..shuffle();
    _flipped = false;
  }

  int _totalIn(String cat) => cat == 'all' ? kFlashcards.length : kFlashcards.where((c) => c.cat == cat).length;

  int get _knownHere => kFlashcards.where((c) => _inCat(c) && _known.contains(c.id)).length;

  Future<void> _gotIt() async {
    if (_deck.isEmpty) return;
    final c = _deck.first;
    setState(() {
      _deck.removeAt(0);
      _known = {..._known, c.id};
      _flipped = false;
    });
    await FlashcardStore.markKnown(c.id);
  }

  void _again() {
    if (_deck.isEmpty) return;
    setState(() {
      final c = _deck.removeAt(0);
      _deck.add(c);
      _flipped = false;
    });
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress? / रीसेट करें?'),
        content: const Text('All cards will come back.\nसभी कार्ड फिर से आ जाएँगे।'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel / रद्द')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset / रीसेट')),
        ],
      ),
    );
    if (ok != true) return;
    await FlashcardStore.reset();
    if (!mounted) return;
    setState(() {
      _known = <String>{};
      _rebuildDeck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = <String>['all', ...kFlashCats.keys];
    final total = _totalIn(_cat);
    final done = _knownHere;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards / फ्लैशकार्ड'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final c in cats) _chip(c)],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 8,
                    backgroundColor: AppC.chip,
                    color: AppC.gold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$done / $total learned • ${_deck.length} left\n$done / $total याद • ${_deck.length} बाकी',
                  style: TextStyle(color: AppC.text54, fontSize: 11.5, height: 1.35),
                ),
                const SizedBox(height: 14),
                if (_deck.isEmpty) _doneBox() else ..._cardArea(_deck.first),
              ],
            ),
    );
  }

  List<Widget> _cardArea(Flashcard c) {
    return [
      _card(c),
      const SizedBox(height: 14),
      if (!_flipped)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _flipped = true),
            icon: const Icon(Icons.visibility),
            label: const Text('Show answer / जवाब देखें'),
          ),
        )
      else
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _again,
                child: const Text('Again / फिर से'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _gotIt,
                child: const Text('Got it ✓ / याद'),
              ),
            ),
          ],
        ),
    ];
  }

  Widget _card(Flashcard c) {
    final v = kFlashCats[c.cat];
    final label = v == null ? '' : '${v[2]} ${v[0]} / ${v[1]}';
    return GestureDetector(
      onTap: () => setState(() => _flipped = !_flipped),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 240),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _flipped ? AppC.goldWash : AppC.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _flipped ? AppC.gold : AppC.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppC.text54, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Text(
              _flipped ? 'ANSWER / उत्तर' : 'QUESTION / प्रश्न',
              style: TextStyle(color: AppC.mutedBlue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              _flipped ? c.a : c.q,
              style: TextStyle(color: AppC.text, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 8),
            Text(
              _flipped ? c.ah : c.qh,
              style: TextStyle(color: AppC.text70, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _flipped ? 'Tap to see the question / सवाल देखने के लिए दबाएँ' : 'Tap card to flip / पलटने के लिए दबाएँ',
                style: TextStyle(color: AppC.text38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppC.line),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            'All cards learned in this topic!\nइस विषय के सभी कार्ड याद हो गए!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick another topic or reset.\nदूसरा विषय चुनें या रीसेट करें।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text54, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset / रीसेट'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String cat) {
    final active = cat == _cat;
    final v = kFlashCats[cat];
    final emoji = v == null ? '🃏' : v[2];
    final name = cat == 'all' ? 'All / सभी' : '${v == null ? cat : v[0]} / ${v == null ? '' : v[1]}';
    return GestureDetector(
      onTap: () => setState(() {
        _cat = cat;
        _rebuildDeck();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppC.gold : AppC.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? AppC.gold : AppC.line),
        ),
        child: Text(
          '$emoji $name (${_totalIn(cat)})',
          style: TextStyle(color: active ? AppC.onGold : AppC.text, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ),
    );
  }
}
