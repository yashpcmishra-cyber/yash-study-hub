import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/exam_tracker_store.dart';
import '../widgets/state_views.dart';

/// Exam Tracker: kaun-kaun se exam ke form bharne hain, last date kab hai, exam
/// kab hai, admit card nikala ya nahi - sab ek jagah, countdown ke saath.
/// Sab data phone me hai - Firestore ko 0 reads / 0 writes.
class ExamTrackerScreen extends StatefulWidget {
  const ExamTrackerScreen({super.key});

  @override
  State<ExamTrackerScreen> createState() => _ExamTrackerScreenState();
}

class _ExamTrackerScreenState extends State<ExamTrackerScreen> {
  List<TrackedExam>? _items;

  @override
  void initState() {
    super.initState();
    ExamTrackerStore.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ExamTrackerStore.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ExamTrackerStore.all();
    if (!mounted) return;
    setState(() => _items = ExamTrackerStore.sorted(list));
  }

  static String _fmt(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _openEditor([TrackedExam? existing]) async {
    final result = await showModalBottomSheet<TrackedExam>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ExamEditor(existing: existing),
    );
    if (result == null) return;
    final ok = await ExamTrackerStore.save(result);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limit reached (25 exams). Delete an old one first. / सीमा पूरी (25)। पहले कोई पुराना हटाएँ।')),
      );
    }
  }

  Future<void> _toggle(TrackedExam e, {bool? applied, bool? feePaid, bool? admitCard}) async {
    await ExamTrackerStore.save(e.copyWith(applied: applied, feePaid: feePaid, admitCard: admitCard));
  }

  Future<void> _delete(TrackedExam e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${e.name}"? / "${e.name}" हटाएँ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete / हटाएँ')),
        ],
      ),
    );
    if (yes == true) await ExamTrackerStore.remove(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Tracker / परीक्षा ट्रैकर')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppC.gold,
        foregroundColor: AppC.onGold,
        icon: const Icon(Icons.add),
        label: const Text('Add exam / जोड़ें'),
      ),
      body: items == null
          ? const LoadingView()
          : items.isEmpty
              ? const EmptyView('No exams yet.\nTap "Add exam" to track form dates, exam dates and admit cards.\n\nअभी कोई परीक्षा नहीं।\n"जोड़ें" दबाकर फॉर्म की तारीख़, परीक्षा की तारीख़ और एडमिट कार्ड ट्रैक करें।')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _card(items[i]),
                ),
    );
  }

  Widget _card(TrackedExam e) {
    final form = e.formDay;
    final exam = e.examDay;
    final int formDays = form == null ? 0 : ExamTrackerStore.daysUntil(form);
    final int examDays = exam == null ? 0 : ExamTrackerStore.daysUntil(exam);
    final urgent = form != null && !e.applied && formDays >= 0 && formDays <= 3;
    final missed = form != null && !e.applied && formDays < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgent ? AppC.red : AppC.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.name, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15.5)),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppC.text54),
                onSelected: (v) {
                  if (v == 'edit') _openEditor(e);
                  if (v == 'delete') _delete(e);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit / बदलें')),
                  PopupMenuItem(value: 'delete', child: Text('Delete / हटाएँ')),
                ],
              ),
            ],
          ),
          if (form != null)
            _dateLine(
              '📝',
              'Form last date / फॉर्म अंतिम तिथि',
              _fmt(form),
              e.applied ? 'Applied ✓ / फॉर्म भरा ✓' : _left(formDays, 'closed / बंद'),
              e.applied ? AppC.green : (urgent || missed ? AppC.red : AppC.mid),
            ),
          if (exam != null)
            _dateLine(
              '🗓️',
              'Exam date / परीक्षा तिथि',
              _fmt(exam),
              _left(examDays, 'over / हो गई'),
              examDays < 0 ? AppC.text54 : AppC.accent,
            ),
          if (e.note.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Text(e.note.trim(), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text54, fontSize: 12, height: 1.3)),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _check('Form filled / फॉर्म भरा', e.applied, () => _toggle(e, applied: !e.applied)),
              _check('Fee paid / फीस दी', e.feePaid, () => _toggle(e, feePaid: !e.feePaid)),
              _check('Admit card / एडमिट कार्ड', e.admitCard, () => _toggle(e, admitCard: !e.admitCard)),
            ],
          ),
        ],
      ),
    );
  }

  String _left(int days, String over) {
    if (days < 0) return over;
    if (days == 0) return 'Today! / आज!';
    if (days == 1) return '1 day left / 1 दिन बाकी';
    return '$days days left / $days दिन बाकी';
  }

  Widget _dateLine(String emoji, String label, String date, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label: $date', style: TextStyle(color: AppC.text70, fontSize: 12.5)),
                Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _check(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: on ? AppC.greenWash : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppC.green : AppC.text24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(on ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: on ? AppC.green : AppC.text54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: on ? AppC.green : AppC.text70, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Add / Edit ka bottom sheet.
class _ExamEditor extends StatefulWidget {
  final TrackedExam? existing;
  const _ExamEditor({this.existing});

  @override
  State<_ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends State<_ExamEditor> {
  static const List<String> _quick = [
    'SSC CGL', 'SSC CHSL', 'SSC MTS', 'SSC GD', 'UP Police', 'Railway NTPC', 'Railway Group D',
    'IBPS PO', 'IBPS Clerk', 'SBI PO', 'SBI Clerk', 'UPSC CSE', 'CTET', 'UPTET', 'NDA', 'CDS',
  ];

  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.existing?.note ?? '');
  DateTime? _form;
  DateTime? _exam;
  String? _error;

  @override
  void initState() {
    super.initState();
    _form = widget.existing?.formDay;
    _exam = widget.existing?.examDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 4, 12, 31);
    var initial = current ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    return showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the exam name. / परीक्षा का नाम लिखें।');
      return;
    }
    final old = widget.existing;
    Navigator.of(context).pop(TrackedExam(
      id: old?.id ?? ExamTrackerStore.newId(),
      name: name.length > 60 ? name.substring(0, 60) : name,
      formLast: _form == null ? '' : ExamTrackerStore.dayKey(_form!),
      examDate: _exam == null ? '' : ExamTrackerStore.dayKey(_exam!),
      applied: old?.applied ?? false,
      feePaid: old?.feePaid ?? false,
      admitCard: old?.admitCard ?? false,
      note: _note.text.trim().length > 200 ? _note.text.trim().substring(0, 200) : _note.text.trim(),
    ));
  }

  String _fmt(DateTime? d) => d == null ? 'Not set / तय नहीं' : _ExamTrackerScreenState._fmt(d);

  Widget _dateRow(String label, DateTime? value, VoidCallback onPick, VoidCallback onClear) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: AppC.text54, fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(_fmt(value), style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(icon: Icon(Icons.calendar_month, color: AppC.accent), onPressed: onPick),
          if (value != null) IconButton(icon: Icon(Icons.close, color: AppC.text54), onPressed: onClear),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add exam / परीक्षा जोड़ें' : 'Edit exam / परीक्षा बदलें',
                style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 60,
              style: TextStyle(color: AppC.text),
              decoration: InputDecoration(
                labelText: 'Exam name / परीक्षा का नाम',
                labelStyle: TextStyle(color: AppC.text54),
                counterText: '',
                filled: true,
                fillColor: AppC.card2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in _quick)
                  GestureDetector(
                    onTap: () => setState(() {
                      _name.text = q;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppC.chip, borderRadius: BorderRadius.circular(16)),
                      child: Text(q, style: TextStyle(color: AppC.text70, fontSize: 11.5)),
                    ),
                  ),
              ],
            ),
            _dateRow('Form last date / फॉर्म की अंतिम तिथि', _form, () async {
              final d = await _pick(_form);
              if (d != null) setState(() => _form = d);
            }, () => setState(() => _form = null)),
            _dateRow('Exam date / परीक्षा की तिथि', _exam, () async {
              final d = await _pick(_exam);
              if (d != null) setState(() => _exam = d);
            }, () => setState(() => _exam = null)),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              style: TextStyle(color: AppC.text),
              decoration: InputDecoration(
                labelText: 'Note (optional) / नोट (वैकल्पिक)',
                labelStyle: TextStyle(color: AppC.text54),
                counterText: '',
                filled: true,
                fillColor: AppC.card2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
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
