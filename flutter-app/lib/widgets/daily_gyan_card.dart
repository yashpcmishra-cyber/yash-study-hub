import 'package:flutter/material.dart';
import '../app_colors.dart';
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

  /// Words A-Z ki tarah paas-paas na aayein, isliye har din kuch aage ka word
  /// liya jaata hai (step list ki lambai se coprime hota hai, to har word
  /// ek cycle mein ek baar hi aata hai).
  static GyanWord _wordFor(DateTime d) {
    final n = kGyanWords.length;
    var step = 37;
    if (_gcd(step, n) != 1) step = 1;
    final i = (((_dayIndex(d) * step) % n) + n) % n;
    return kGyanWords[i];
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
    ShareService.custom(
      context,
      '📖 Word of the Day: ${w.word}',
      '${w.word} (${w.pos}) = ${w.hi} (${w.en})\n'
      'Synonyms: ${w.syn.join(', ')}\n'
      'Antonyms: ${w.ant.join(', ')}\n'
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
          Text('${w.word} (${w.pos}) - ${w.hi}', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(w.en, style: TextStyle(color: AppC.text70, fontSize: 12.5)),
          Text('Syn: ${w.syn.join(', ')}', style: TextStyle(color: AppC.text70, fontSize: 12)),
          Text('Ant: ${w.ant.join(', ')}', style: TextStyle(color: AppC.text70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('💡 ${f.en}', style: TextStyle(color: AppC.text, fontSize: 12.5, height: 1.35)),
          Text(f.hi, style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.35)),
        ],
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(w.word, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 22)),
                    ),
                    const SizedBox(width: 8),
                    Text(w.pos, style: TextStyle(color: AppC.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(w.hi, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14.5)),
                Text(w.en, style: TextStyle(color: AppC.text70, fontSize: 13)),
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
