import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/study_time_store.dart';

/// Pichhle 7 din ki padhai (Study Timer se) ka bar chart.
/// Data sirf phone me hai - Firestore ko 0 reads.
class StudyTimeChart extends StatefulWidget {
  const StudyTimeChart({super.key});

  @override
  State<StudyTimeChart> createState() => _StudyTimeChartState();
}

class _StudyTimeChartState extends State<StudyTimeChart> {
  List<DayStudy> _days = const <DayStudy>[];

  static const List<String> _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    StudyTimeStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    StudyTimeStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await StudyTimeStore.last7();
      if (!mounted) return;
      setState(() => _days = d);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    var total = 0;
    var maxSec = 1800; // chart kam se kam 30 minute tak scale hota hai
    for (final d in _days) {
      total += d.seconds;
      if (d.seconds > maxSec) maxSec = d.seconds;
    }
    const maxBar = 80.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '⏱️ Study time this week / इस हफ़्ते की पढ़ाई',
                  style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              Text(StudyTimeStore.fmt(total), style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 122,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _days.length; i++) _bar(_days[i], i == _days.length - 1, maxSec, maxBar),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the Study Timer to fill this chart.\nइस चार्ट को भरने के लिए Study Timer चलाएँ।',
            style: TextStyle(color: AppC.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _bar(DayStudy d, bool today, int maxSec, double maxBar) {
    final h = d.seconds <= 0 ? 3.0 : (maxBar * d.seconds / maxSec).clamp(4.0, maxBar).toDouble();
    final Color c = d.seconds <= 0 ? AppC.text12 : (today ? AppC.accent : AppC.green);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(d.seconds <= 0 ? '' : StudyTimeStore.fmt(d.seconds), style: TextStyle(color: AppC.text70, fontSize: 10)),
            ),
            const SizedBox(height: 3),
            Container(height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Text(
              _names[d.day.weekday - 1],
              style: TextStyle(color: today ? AppC.text : AppC.muted, fontSize: 10, fontWeight: today ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
