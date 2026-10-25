import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/daily_gyan_data.dart';
import '../services/share_service.dart';

/// Home ka "Aaj ka Gyaan" card: Word of the Day + ek GK fact.
/// Roz date ke hisaab se badalta hai. Content app ke andar hai -
/// Firestore ko 0 reads / 0 writes.
class DailyGyanCard extends StatelessWidget {
  const DailyGyanCard({super.key});

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 1 Jan 2024 se kitne din hue (phone ki local date se).
  static int _dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024, 1, 1)).inDays;

  static GyanWord _wordFor(DateTime d) {
    final n = kGyanWords.length;
    return kGyanWords[((_dayIndex(d) % n) + n) % n];
  }

  static GyanFact _factFor(DateTime d) {
    final n = kGyanFacts.length;
    return kGyanFacts[((_dayIndex(d) % n) + n) % n];
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
      '${w.word} = ${w.hi} (${w.en})\nExample: ${w.example}\n\n💡 ${f.en}\n${f.hi}',
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
          Text('${w.word} - ${w.hi}', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(w.en, style: TextStyle(color: AppC.text70, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text('💡 ${f.en}', style: TextStyle(color: AppC.text, fontSize: 12.5, height: 1.35)),
          Text(f.hi, style: TextStyle(color: AppC.text70, fontSize: 12.5, height: 1.35)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final w = _wordFor(now);
    final f = _factFor(now);
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
                Text(w.word, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 2),
                Text(w.hi, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14.5)),
                Text(w.en, style: TextStyle(color: AppC.text70, fontSize: 13)),
                const SizedBox(height: 6),
                Text('“${w.example}”', style: TextStyle(color: AppC.text60, fontSize: 12.5, fontStyle: FontStyle.italic, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('💡 Did you know? / क्या आप जानते हैं?', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(f.en, style: TextStyle(color: AppC.text, fontSize: 13, height: 1.35)),
          const SizedBox(height: 2),
          Text(f.hi, style: TextStyle(color: AppC.text70, fontSize: 13, height: 1.35)),
        ],
      ),
    );
  }
}
