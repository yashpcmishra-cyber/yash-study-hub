import 'dart:math';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/mock_rank_service.dart';
import '../services/score_journal_store.dart';
import '../widgets/state_views.dart';

/// Score Journal: kisi bhi test series ka score yahan likho (Testbook, Adda247,
/// coaching test ...). Average, best aur trend graph apne aap dikhta hai.
/// Sab data phone me hai - Firestore ko 0 reads / 0 writes.
class ScoreJournalScreen extends StatefulWidget {
  const ScoreJournalScreen({super.key});

  @override
  State<ScoreJournalScreen> createState() => _ScoreJournalScreenState();
}

class _ScoreJournalScreenState extends State<ScoreJournalScreen> {
  List<ScoreEntry>? _items; // nayi pehle

  @override
  void initState() {
    super.initState();
    ScoreJournalStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ScoreJournalStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ScoreJournalStore.all();
    if (!mounted) return;
    setState(() => _items = list);
  }

  static String _fmt(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<ScoreEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _ScoreEditor(),
    );
    if (result == null) return;
    await ScoreJournalStore.add(result);
  }

  Future<void> _delete(ScoreEntry e) async {
    await ScoreJournalStore.remove(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Removed / हटा दिया'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Undo', onPressed: () => ScoreJournalStore.add(e)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Score Journal / स्कोर जर्नल')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppC.gold,
        foregroundColor: AppC.onGold,
        icon: const Icon(Icons.add),
        label: const Text('Add score / स्कोर जोड़ें'),
      ),
      body: items == null
          ? const LoadingView()
          : items.isEmpty
              ? const EmptyView('No scores yet.\nAfter any test, tap "Add score" to track your progress.\n\nअभी कोई स्कोर नहीं।\nकिसी भी टेस्ट के बाद "स्कोर जोड़ें" दबाकर अपनी प्रगति देखें।')
              : _content(items),
    );
  }

  Widget _content(List<ScoreEntry> items) {
    var sum = 0.0;
    var best = items.first.percent;
    for (final e in items) {
      sum += e.percent;
      if (e.percent > best) best = e.percent;
    }
    final avg = sum / items.length;
    // Trend: sabse nayi 3 test ka average vs uske pehle ke test ka average.
    String trend = '';
    Color trendColor = AppC.text54;
    if (items.length >= 4) {
      final recent = items.take(3).map((e) => e.percent).reduce((a, b) => a + b) / 3;
      final older = items.skip(3).map((e) => e.percent).reduce((a, b) => a + b) / (items.length - 3);
      final diff = recent - older;
      if (diff >= 1) {
        trend = '▲ +${diff.toStringAsFixed(1)}%';
        trendColor = AppC.green;
      } else if (diff <= -1) {
        trend = '▼ ${diff.toStringAsFixed(1)}%';
        trendColor = AppC.red;
      } else {
        trend = '＝ steady / स्थिर';
      }
    }
    final chartVals = items.take(12).toList().reversed.map((e) => e.percent).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        Row(
          children: [
            _stat('Tests / टेस्ट', '${items.length}'),
            const SizedBox(width: 8),
            _stat('Average / औसत', '${avg.round()}%'),
            const SizedBox(width: 8),
            _stat('Best / बेस्ट', '${best.round()}%'),
          ],
        ),
        if (trend.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text('Last 3 tests vs earlier / पिछले 3 टेस्ट बनाम पहले:  $trend',
                style: TextStyle(color: trendColor, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        const SizedBox(height: 12),
        Container(
          height: 170,
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
          decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppC.line)),
          child: chartVals.length < 2
              ? Center(child: Text('Add one more score to see the graph.\nग्राफ देखने के लिए एक और स्कोर जोड़ें।', textAlign: TextAlign.center, style: TextStyle(color: AppC.text54, fontSize: 12.5)))
              : CustomPaint(
                  size: Size.infinite,
                  painter: _TrendPainter(chartVals, AppC.accent, AppC.line, AppC.text54, AppC.gold),
                ),
        ),
        const SizedBox(height: 14),
        Text('All scores / सभी स्कोर', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        for (final e in items) _row(e),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppC.line)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 19)),
            const SizedBox(height: 3),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: TextStyle(color: AppC.text54, fontSize: 11))),
          ],
        ),
      ),
    );
  }

  Widget _row(ScoreEntry e) {
    final pct = e.percent;
    final color = pct >= 70 ? AppC.green : (pct >= 40 ? AppC.mid : AppC.red);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppC.line)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  e.note.trim().isEmpty ? _fmt(e.date) : '${_fmt(e.date)}  •  ${e.note.trim()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppC.text38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmtMarks(e.score)} / ${fmtMarks(e.total)}', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${pct.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: AppC.text38, size: 20),
            onPressed: () => _delete(e),
          ),
        ],
      ),
    );
  }
}

/// Score ka line graph (0-100%). Values purani se nayi ki taraf.
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color dotColor;
  _TrendPainter(this.values, this.lineColor, this.gridColor, this.textColor, this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, top = 6.0, right = 6.0, bottom = 6.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0 || values.length < 2) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final pct = i * 25;
      final y = top + h - (h * pct / 100);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      final tp = TextPainter(
        text: TextSpan(text: '$pct', style: TextStyle(color: textColor, fontSize: 9.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, y - tp.height / 2));
    }

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = max(0.0, min(100.0, values[i]));
      final x = left + w * i / (values.length - 1);
      final y = top + h - (h * v / 100);
      pts.add(Offset(x, y));
    }
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = dotColor;
    final ring = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dot);
      canvas.drawCircle(p, 4, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}

/// Naya score jodne ka bottom sheet.
class _ScoreEditor extends StatefulWidget {
  const _ScoreEditor();

  @override
  State<_ScoreEditor> createState() => _ScoreEditorState();
}

class _ScoreEditorState extends State<_ScoreEditor> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _score = TextEditingController();
  final TextEditingController _total = TextEditingController(text: '100');
  final TextEditingController _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _score.dispose();
    _total.dispose();
    _note.dispose();
    super.dispose();
  }

  double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    final name = _name.text.trim();
    final score = _num(_score.text);
    final total = _num(_total.text);
    if (name.isEmpty) {
      setState(() => _error = 'Enter the test name. / टेस्ट का नाम लिखें।');
      return;
    }
    if (score == null || total == null || total <= 0) {
      setState(() => _error = 'Enter valid marks. / सही अंक लिखें।');
      return;
    }
    if (score > total || score < -total) {
      setState(() => _error = 'Score cannot be more than the total marks. / स्कोर कुल अंकों से ज़्यादा नहीं हो सकता।');
      return;
    }
    final note = _note.text.trim();
    Navigator.of(context).pop(ScoreEntry(
      id: ScoreJournalStore.newId(),
      name: name.length > 60 ? name.substring(0, 60) : name,
      score: score,
      total: total,
      ms: DateTime(_date.year, _date.month, _date.day, 12).millisecondsSinceEpoch,
      note: note.length > 100 ? note.substring(0, 100) : note,
    ));
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppC.text54),
        counterText: '',
        filled: true,
        fillColor: AppC.card2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const numKb = TextInputType.numberWithOptions(decimal: true, signed: true);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add score / स्कोर जोड़ें', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: _name, maxLength: 60, style: TextStyle(color: AppC.text), decoration: _dec('Test name / टेस्ट का नाम')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _score, keyboardType: numKb, style: TextStyle(color: AppC.text), decoration: _dec('Your score / आपका स्कोर'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _total, keyboardType: numKb, style: TextStyle(color: AppC.text), decoration: _dec('Out of / कुल अंक'))),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: AppC.accent, size: 20),
                    const SizedBox(width: 10),
                    Text('Date / तारीख़: ${_ScoreJournalScreenState._fmt(_date)}', style: TextStyle(color: AppC.text, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _note, maxLength: 100, style: TextStyle(color: AppC.text), decoration: _dec('Note, e.g. weak topics (optional) / नोट (वैकल्पिक)')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: AppC.red, fontSize: 12.5)),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Save / सेव करें')),
            ),
          ],
        ),
      ),
    );
  }
}
