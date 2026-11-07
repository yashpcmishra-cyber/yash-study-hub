import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/important_days_data.dart';
import '../services/calendar_store.dart';
import '../services/study_store.dart';
import '../services/study_time_store.dart';
import '../widgets/state_views.dart';

/// Study Calendar: mahine ka heatmap - kis din kitna padha (sawal + Study Timer).
/// Din par tap = us din ka hisaab. Exam ki date 🎯 se dikhti hai.
/// Sab data phone me hai - Firestore ko 0 reads / 0 writes.
class StudyCalendarScreen extends StatefulWidget {
  const StudyCalendarScreen({super.key});

  @override
  State<StudyCalendarScreen> createState() => _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends State<StudyCalendarScreen> {
  static const int _maxBackMonths = 24;

  late DateTime _month; // mahine ki 1 tareekh
  DateTime? _sel;
  Map<String, DayActivity>? _data;
  ExamTarget? _exam;
  int _goalStreak = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final t = _today();
    _month = DateTime(t.year, t.month, 1);
    _sel = t;
    StudyStore.changes.addListener(_load);
    StudyTimeStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    StudyStore.changes.removeListener(_load);
    StudyTimeStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final data = await CalendarStore.all();
    ExamTarget? exam;
    var streak = 0;
    try {
      exam = await StudyStore.readExam();
      streak = (await StudyStore.readStreak()).days;
    } catch (_) {
      // exam / streak na mile to bhi calendar dikhe
    }
    if (!mounted) return;
    setState(() {
      _data = data;
      _exam = exam;
      _goalStreak = streak;
    });
  }

  bool get _isCurrentMonth {
    final t = _today();
    return _month.year == t.year && _month.month == t.month;
  }

  bool get _canGoBack {
    final t = _today();
    final diff = (t.year - _month.year) * 12 + (t.month - _month.month);
    return diff < _maxBackMonths;
  }

  void _shift(int delta) {
    final m = DateTime(_month.year, _month.month + delta, 1);
    final t = _today();
    final sel = (m.year == t.year && m.month == t.month) ? t : null;
    setState(() {
      _month = m;
      _sel = sel;
    });
  }

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  DayActivity _act(DateTime d) => _data?[CalendarStore.keyOf(d)] ?? DayActivity.none;

  bool _isExamDay(DateTime d) {
    final e = _exam?.date;
    return e != null && e.year == d.year && e.month == d.month && e.day == d.day;
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1:
        return AppC.accent.withOpacity(0.18);
      case 2:
        return AppC.accent.withOpacity(0.38);
      case 3:
        return AppC.accent.withOpacity(0.65);
      case 4:
        return AppC.accent.withOpacity(0.95);
      default:
        return AppC.card;
    }
  }

  Color _levelText(int level) {
    if (level >= 3) return AppTheme.isLight ? Colors.white : AppC.onGold;
    return AppC.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Calendar / स्टडी कैलेंडर')),
      body: _data == null ? const LoadingView() : _content(),
    );
  }

  Widget _content() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _header(),
        const SizedBox(height: 8),
        _weekdayRow(),
        const SizedBox(height: 6),
        _grid(),
        const SizedBox(height: 8),
        _legend(),
        const SizedBox(height: 14),
        if (_sel != null) _dayCard(_sel!),
        _summary(),
        const SizedBox(height: 10),
        Text(
          'Active day = at least 1 question or 1 minute on the Study Timer.\nएक्टिव दिन = कम से कम 1 सवाल या स्टडी टाइमर का 1 मिनट।',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppC.muted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          color: AppC.text,
          onPressed: _canGoBack ? () => _shift(-1) : null,
        ),
        Expanded(
          child: Text(
            '${kMonthNames[_month.month - 1]} ${_month.year}',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
          color: AppC.text,
          onPressed: _isCurrentMonth ? null : () => _shift(1),
        ),
      ],
    );
  }

  Widget _weekdayRow() {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(child: Text(l, style: TextStyle(color: AppC.text54, fontWeight: FontWeight.bold, fontSize: 12))),
          ),
      ],
    );
  }

  Widget _grid() {
    final lead = DateTime(_month.year, _month.month, 1).weekday % 7; // Sunday = 0
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= _daysInMonth; d++) _cell(d),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      children: cells,
    );
  }

  Widget _cell(int day) {
    final d = DateTime(_month.year, _month.month, day);
    final future = d.isAfter(_today());
    final a = _act(d);
    final level = future ? 0 : a.level;
    final isToday = d == _today();
    final isSel = _sel != null && d == _sel;
    final exam = _isExamDay(d);

    Border? border;
    if (isSel) {
      border = Border.all(color: AppC.text, width: 2);
    } else if (isToday) {
      border = Border.all(color: AppC.accent, width: 2);
    } else if (level == 0) {
      border = Border.all(color: AppC.line);
    }

    return GestureDetector(
      onTap: () => setState(() => _sel = d),
      child: Container(
        decoration: BoxDecoration(
          color: future ? Colors.transparent : _levelColor(level),
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: future ? AppC.text30 : _levelText(level),
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (exam)
              const Positioned(
                right: 2,
                bottom: 0,
                child: Text('🎯', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Less / कम', style: TextStyle(color: AppC.muted, fontSize: 11)),
        const SizedBox(width: 6),
        for (var l = 0; l <= 4; l++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _levelColor(l),
              borderRadius: BorderRadius.circular(4),
              border: l == 0 ? Border.all(color: AppC.line) : null,
            ),
          ),
        const SizedBox(width: 6),
        Text('More / ज़्यादा', style: TextStyle(color: AppC.muted, fontSize: 11)),
      ],
    );
  }

  String _dayLabel(DateTime d) {
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${d.day} ${kMonthShort[d.month - 1]} ${d.year}  •  ${wd[d.weekday - 1]}';
  }

  Widget _dayCard(DateTime d) {
    final future = d.isAfter(_today());
    final a = _act(d);
    final specials = kImportantDays.where((e) => e.month == d.month && e.day == d.day).take(2).toList();
    final exam = _isExamDay(d);
    final examName = (_exam?.name ?? '').trim();
    final String body;
    if (future) {
      body = 'This day has not come yet.\nयह दिन अभी आया नहीं है।';
    } else if (!a.active && a.questions == 0 && a.seconds == 0) {
      body = 'No study recorded on this day.\nइस दिन कोई पढ़ाई दर्ज नहीं है।';
    } else {
      body = '📝 Questions: ${a.questions}   •   ⏱️ Study time: ${StudyTimeStore.fmt(a.seconds)}';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dayLabel(d), style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: AppC.text70, fontSize: 13, height: 1.4)),
          if (exam)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('🎯 Exam day${examName.isEmpty ? '' : ': $examName'} / परीक्षा का दिन', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          for (final s in specials)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📅 ${s.en}  (${s.hi})', style: TextStyle(color: AppC.text54, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _statTile(String big, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppC.line)),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(big, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppC.text54, fontSize: 10.5, height: 1.25)),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final today = _today();
    var active = 0;
    var questions = 0;
    var seconds = 0;
    var run = 0;
    var best = 0;
    final lastDay = _isCurrentMonth ? today.day : _daysInMonth;
    for (var day = 1; day <= lastDay; day++) {
      final a = _act(DateTime(_month.year, _month.month, day));
      if (a.active) {
        active++;
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
      questions += a.questions;
      seconds += a.seconds;
    }
    return Column(
      children: [
        Row(children: [
          _statTile('$active / $lastDay', 'Active days\nएक्टिव दिन'),
          const SizedBox(width: 8),
          _statTile('$questions', 'Questions\nसवाल'),
          const SizedBox(width: 8),
          _statTile(StudyTimeStore.fmt(seconds), 'Study time\nपढ़ाई का समय'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _statTile('$best', 'Best run (days)\nसबसे लंबा सिलसिला'),
          const SizedBox(width: 8),
          _statTile('🔥 $_goalStreak', 'Goal streak\nगोल स्ट्रीक'),
        ]),
      ],
    );
  }
}
