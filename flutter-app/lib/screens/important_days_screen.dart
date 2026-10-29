import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/important_days_data.dart';

/// Aaj ka important din (agar hai) ya agla aane wala din - Home ke tile ke liye.
String importantDayTileText() {
  final now = DateTime.now();
  final today = kImportantDays.where((d) => d.month == now.month && d.day == now.day).toList();
  if (today.isNotEmpty) return 'Today: ${today.first.en}';
  ImportantDay? best;
  var bestGap = 9999;
  for (final d in kImportantDays) {
    final target = DateTime(now.year, d.month, d.day);
    final when = target.isBefore(DateTime(now.year, now.month, now.day)) ? DateTime(now.year + 1, d.month, d.day) : target;
    final gap = when.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (gap < bestGap) {
      bestGap = gap;
      best = d;
    }
  }
  if (best == null) return 'National & world days';
  return 'Next: ${kMonthShort[best.month - 1]} ${best.day}';
}

/// Important Days: SSC / Banking / UP exams me poochhe jaane wale rashtriya,
/// antarrashtriya aur rajya diwas. App me bundled - Firestore ko 0 reads / 0 writes.
class ImportantDaysScreen extends StatefulWidget {
  const ImportantDaysScreen({super.key});

  @override
  State<ImportantDaysScreen> createState() => _ImportantDaysScreenState();
}

class _ImportantDaysScreenState extends State<ImportantDaysScreen> {
  late int _month; // 0 = saare mahine
  String _type = 'all'; // all | india | world | state
  String _q = '';
  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = _now.month;
  }

  List<ImportantDay> get _list {
    final q = _q.trim().toLowerCase();
    final out = kImportantDays.where((d) {
      if (_type != 'all' && d.type != _type) return false;
      if (q.isNotEmpty) return d.en.toLowerCase().contains(q) || d.hi.contains(_q.trim());
      return _month == 0 || d.month == _month;
    }).toList();
    out.sort((a, b) => a.month != b.month ? a.month.compareTo(b.month) : a.day.compareTo(b.day));
    return out;
  }

  bool _isToday(ImportantDay d) => d.month == _now.month && d.day == _now.day;

  String _typeLabel(String t) {
    switch (t) {
      case 'india':
        return 'India';
      case 'world':
        return 'World';
      case 'state':
        return 'State';
    }
    return '';
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'india':
        return AppC.orange;
      case 'world':
        return AppC.sky;
    }
    return AppC.green;
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final todays = kImportantDays.where(_isToday).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Important Days / महत्वपूर्ण दिवस')),
      body: Column(
        children: [
          if (todays.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📅 Today / आज", style: TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  for (final d in todays)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${d.en}\n${d.hi}', style: const TextStyle(color: AppC.onGold, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(color: AppC.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search all days / सभी दिवस खोजें',
                hintStyle: TextStyle(color: AppC.text38),
                prefixIcon: Icon(Icons.search, color: AppC.text54),
                filled: true,
                fillColor: AppC.card,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', _month == 0, () => setState(() => _month = 0)),
                for (var m = 1; m <= 12; m++) _chip(kMonthShort[m - 1], _month == m, () => setState(() => _month = m)),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All types', _type == 'all', () => setState(() => _type = 'all')),
                _chip('🇮🇳 India', _type == 'india', () => setState(() => _type = 'india')),
                _chip('🌍 World', _type == 'world', () => setState(() => _type = 'world')),
                _chip('🏛️ State', _type == 'state', () => setState(() => _type = 'state')),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('No days found.\nकोई दिवस नहीं मिला।', textAlign: TextAlign.center, style: TextStyle(color: AppC.text54)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length + 1,
                    itemBuilder: (_, i) {
                      if (i == list.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Only fixed-date days are listed (festivals like Diwali / Holi change every year).\nसिर्फ़ तय तारीख वाले दिन हैं (दिवाली / होली जैसे त्योहार हर साल बदलते हैं)।',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppC.muted, fontSize: 11),
                          ),
                        );
                      }
                      return _row(list[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppC.gold : AppC.chip,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(color: on ? AppC.onGold : AppC.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _row(ImportantDay d) {
    final today = _isToday(d);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: today ? AppC.accent : AppC.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text('${d.day}', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(kMonthShort[d.month - 1], style: TextStyle(color: AppC.text70, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.en, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(d.hi, style: TextStyle(color: AppC.text70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_typeLabel(d.type), style: TextStyle(color: _typeColor(d.type), fontSize: 10.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
