import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/ahc_pyq_data.dart';
import '../data/daily_gyan_data.dart';
import '../services/share_service.dart';

/// Home ka "Aaj ka Gyaan" card:
///  - Word of the Day (Banking PO level) - Hindi meaning, example, synonyms, antonyms
///  - Did you know? (hard-level GS / Science / Static GK / UP GK fact)
/// Roz date ke hisaab se badalta hai. Content app ke andar hai -
/// Firestore ko 0 reads / 0 writes.
class DailyGyanCard extends StatelessWidget {
  const DailyGyanCard({super.key});

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 1 Jan 2024 se kitne din hue (phone ki local date se).
  static int _dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024, 1, 1)).inDays;

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  /// Har kitne din me ek AHC RO/ARO PYQ item aaye (2 = har doosre din,
  /// 3 = har teesre din, 1 = roz, 0 = band). Baaki din normal Banking words.
  static const int _pyqEvery = 2;

  /// PYQ dino ka kram: 0 = Vocabulary, 1 = One Word Substitution, 2 = Idiom.
  /// Is pattern me 8 me se 6 din vocabulary, 1 din OWS, 1 din idiom (list ki
  /// lambai ke hisaab se teeno ki cycle lagbhag barabar chalti hai).
  static const List<int> _pyqPattern = [0, 0, 0, 1, 0, 0, 0, 2];

  static GyanWord _pick(List<GyanWord> list, int counter, int step) {
    final n = list.length;
    var st = step;
    if (_gcd(st, n) != 1) st = 1;
    return list[(((counter * st) % n) + n) % n];
  }

  /// k = ab tak kitne PYQ din hue. Har type ki apni alag cycle hai, isliye
  /// koi word / idiom skip nahi hota aur ek cycle me ek hi baar aata hai.
  static GyanWord _pyqFor(int k) {
    final pl = _pyqPattern.length;
    final p = ((k % pl) + pl) % pl;
    final kind = _pyqPattern[p];
    final per = _pyqPattern.where((x) => x == kind).length;
    final rank = _pyqPattern.sublist(0, p).where((x) => x == kind).length;
    final counter = (k ~/ pl) * per + rank;
    final list = kind == 1 ? kAhcPyqOws : (kind == 2 ? kAhcPyqIdioms : kAhcPyqWords);
    return _pick(list.isEmpty ? kAhcPyqWords : list, counter, 7);
  }

  static GyanWord _wordFor(DateTime d) {
    final di = _dayIndex(d);
    if (_pyqEvery > 0 && kAhcPyqWords.isNotEmpty) {
      if (di % _pyqEvery == 0) return _pyqFor(di ~/ _pyqEvery);
      // Normal words ka counter: sirf non-PYQ dino ko gino, taaki koi word skip na ho.
      return _pick(kGyanWords, di - (di ~/ _pyqEvery) - 1, 37);
    }
    return _pick(kGyanWords, di, 37);
  }

  static bool _special(GyanWord w) => w.pos == 'OWS' || w.pos == 'idiom';

  static String _kindLabel(GyanWord w) {
    if (w.pos == 'OWS') return 'One Word Substitution';
    if (w.pos == 'idiom') return 'Idiom & Phrase';
    return '';
  }

  /// "word (pos)" ya OWS / idiom ke liye sirf "word".
  static String _head(GyanWord w) => _special(w) ? w.word : '${w.word} (${w.pos})';

  /// Badge / share ke liye: "AHC RO/ARO PYQ · One Word Substitution · AHC RO 2019"
  static String _pyqText(GyanWord w) {
    final parts = <String>['AHC RO/ARO PYQ'];
    if (_kindLabel(w).isNotEmpty) parts.add(_kindLabel(w));
    if (w.src.isNotEmpty) parts.add(w.src);
    return parts.join(' · ');
  }

  /// Facts topic ke hisaab se ghul-mil kar: Science, Polity, History,
  /// Geography... ek ke baad ek, taaki roz alag topic mile.
  static final List<GyanFact> _mixedFacts = _mix();

  static List<GyanFact> _mix() {
    final groups = <String, List<GyanFact>>{};
    for (final f in kGyanFacts) {
      groups.putIfAbsent(f.topic, () => <GyanFact>[]).add(f);
    }
    final lists = groups.values.toList();
    final out = <GyanFact>[];
    var round = 0;
    while (out.length < kGyanFacts.length) {
      for (final l in lists) {
        if (round < l.length) out.add(l[round]);
      }
      round++;
    }
    return out;
  }

  static GyanFact _factFor(DateTime d) {
    final n = _mixedFacts.length;
    return _mixedFacts[((_dayIndex(d) % n) + n) % n];
  }

  static String _topicLabel(String topic) {
    switch (topic) {
      case 'Science':
        return '🔬 General Science / सामान्य विज्ञान';
      case 'Polity':
        return '🏛️ Polity / राजव्यवस्था';
      case 'History':
        return '📜 History / इतिहास';
      case 'Geography':
        return '🌍 Geography / भूगोल';
      case 'Economy':
        return '💰 Economy / अर्थव्यवस्था';
      case 'StaticGK':
        return '📚 Static GK / स्टैटिक जीके';
      case 'UPGK':
        return '📍 UP GK / यूपी जीके';
      default:
        return '';
    }
  }

  static String _dayLabel(DateTime d, int back) {
    if (back == 0) return 'Today / आज';
    if (back == 1) return 'Yesterday / कल';
    return '${d.day} ${_months[d.month - 1]}';
  }

  void _share(BuildContext context, GyanWord w, GyanFact f) {
    final first = w.pos == 'OWS'
        ? '${w.word} = ${w.en} (${w.hi})\n'
        : (w.pos == 'idiom' ? '${w.word} = ${w.en} (${w.hi})\n' : '${w.word} (${w.pos}) = ${w.hi} (${w.en})\n');
    ShareService.custom(
      context,
      w.pos == 'OWS'
          ? '📖 One Word Substitution: ${w.word}'
          : (w.pos == 'idiom' ? '📖 Idiom: ${w.word}' : '📖 Word of the Day: ${w.word}'),
      first +
          (w.src.isNotEmpty ? '🎯 ${_pyqText(w)}\n' : '') +
          (w.syn.isNotEmpty ? 'Synonyms: ${w.syn.join(', ')}\n' : '') +
          (w.ant.isNotEmpty ? 'Antonyms: ${w.ant.join(', ')}\n' : '') +
          'Example: ${w.example}\n\n'
              '💡 ${f.en}\n${f.hi}',
    );
  }

  void _showPast(BuildContext context) {
    final now = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppC.card2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.75;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Last 7 days / पिछले 7 दिन', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              for (var i = 0; i < 7; i++) _pastRow(DateTime(now.year, now.month, now.day - i), i),
            ],
          ),
        );
      },
    );
  }

  Widget _pastRow(DateTime d, int back) {
    final w = _wordFor(d);
    final f = _factFor(d);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dayLabel(d, back), style: TextStyle(color: AppC.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text('${_head(w)} - ${w.hi}', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(w.en, style: TextStyle(color: AppC.text70, fontSize: 12.5)),
          if (w.src.isNotEmpty) Text('🎯 ${_pyqText(w)}', style: TextStyle(color: AppC.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
          if (w.syn.isNotEmpty) Text('Syn: ${w.syn.join(', ')}', style: TextStyle(color: AppC.text70, fontSize: 12)),
          if (w.ant.isNotEmpty) Text('Ant: ${w.ant.join(', ')}', style: TextStyle(color: AppC.text70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('💡 ${f.en}', style: TextStyle(color: AppC.text, fontSize: 12.5, height: 1.35)),
          Text(f.hi, style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.35)),
        ],
      ),
    );
  }

  Widget _pyqBadge(GyanWord w) {
    if (w.src.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppC.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppC.accent.withOpacity(0.5)),
        ),
        child: Text('🎯 ${_pyqText(w)}', style: TextStyle(color: AppC.accent, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _synAnt(String label, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            TextSpan(text: items.join(', '), style: TextStyle(color: AppC.text70)),
          ],
        ),
        style: const TextStyle(fontSize: 12.5, height: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final w = _wordFor(now);
    final f = _factFor(now);
    final tag = _topicLabel(f.topic);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppC.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppC.tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('📖 Word of the Day / आज का शब्द', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              InkWell(
                onTap: () => _showPast(context),
                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.history, size: 20, color: AppC.text70)),
              ),
              InkWell(
                onTap: () => _share(context, w, f),
                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.share_outlined, size: 20, color: AppC.text70)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pyqBadge(w),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(w.word, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 22)),
                    ),
                    if (!_special(w)) ...[
                      const SizedBox(width: 8),
                      Text(w.pos, style: TextStyle(color: AppC.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(w.hi, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14.5)),
                Text(w.pos == 'OWS' ? 'One word for: ${w.en}' : w.en, style: TextStyle(color: AppC.text70, fontSize: 13)),
                _synAnt('Synonyms', w.syn, AppC.green),
                _synAnt('Antonyms', w.ant, AppC.red),
                const SizedBox(height: 6),
                Text('“${w.example}”', style: TextStyle(color: AppC.text60, fontSize: 12.5, fontStyle: FontStyle.italic, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('💡 Did you know? / क्या आप जानते हैं?', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
          if (tag.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(tag, style: TextStyle(color: AppC.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 4),
          Text(f.en, style: TextStyle(color: AppC.text, fontSize: 13, height: 1.35)),
          const SizedBox(height: 2),
          Text(f.hi, style: TextStyle(color: AppC.text70, fontSize: 13, height: 1.35)),
        ],
      ),
    );
  }
}
