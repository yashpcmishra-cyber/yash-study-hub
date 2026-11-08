import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/checklist_store.dart';

/// Exam Day Checklist: exam se pehle ki tayyari (documents, ek din pehle, saath kya
/// le jayein, centre par). Ticks aur apne items phone me save hote hain -
/// Firestore ko 0 reads / 0 writes.
class ExamChecklistScreen extends StatefulWidget {
  const ExamChecklistScreen({super.key});

  @override
  State<ExamChecklistScreen> createState() => _ExamChecklistScreenState();
}

class _ExamChecklistScreenState extends State<ExamChecklistScreen> {
  ChecklistData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ChecklistStore.load();
    if (!mounted) return;
    setState(() => _data = d);
  }

  Future<void> _toggle(String id) async {
    await ChecklistStore.toggle(id);
    await _load();
  }

  Future<void> _toggleCustom(String id) async {
    await ChecklistStore.toggleCustom(id);
    await _load();
  }

  Future<void> _deleteCustom(String id) async {
    await ChecklistStore.deleteCustom(id);
    await _load();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Untick everything? / सब टिक हटाएँ?'),
        content: const Text('Use this before your next exam. Your own items stay.\nअगली परीक्षा से पहले इस्तेमाल करें। आपके अपने आइटम बने रहेंगे।'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel / रद्द')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Untick all / हटाएँ')),
        ],
      ),
    );
    if (ok == true) {
      await ChecklistStore.untickAll();
      await _load();
    }
  }

  Future<void> _addDialog() async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add your own item / अपना आइटम जोड़ें'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: ChecklistStore.maxText,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Spare photocopy of ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel / रद्द')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('Add / जोड़ें')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final ok = await ChecklistStore.addCustom(text);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limit reached (30 items). Delete one first. / सीमा पूरी (30 आइटम)। पहले एक हटाएँ।')),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Day Checklist / परीक्षा चेकलिस्ट', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(tooltip: 'Untick all / सब टिक हटाएँ', icon: const Icon(Icons.restart_alt), onPressed: d == null ? null : _confirmReset),
        ],
      ),
      body: d == null ? const Center(child: CircularProgressIndicator()) : _body(d),
    );
  }

  Widget _body(ChecklistData d) {
    var total = ChecklistStore.defaultTotal + d.custom.length;
    var done = d.custom.where((e) => e.done).length;
    for (final g in kCheckGroups) {
      for (final it in g.items) {
        if (d.done.contains(it.id)) done++;
      }
    }
    if (total < 1) total = 1;
    final all = done >= total;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppC.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(all ? 'All set! Best of luck 🍀\nसब तैयार! शुभकामनाएँ 🍀' : '$done / $total ready\n$done / $total तैयार', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15, height: 1.35)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: done / total,
                  minHeight: 8,
                  backgroundColor: AppC.soft,
                  valueColor: AlwaysStoppedAnimation<Color>(AppC.gold),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Rules differ for every exam - always follow your own admit card.\nहर परीक्षा के नियम अलग होते हैं - अपने एडमिट कार्ड के निर्देश ही मानें।',
                style: TextStyle(color: AppC.text60, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
        for (final g in kCheckGroups) ...[
          _header('${g.emoji} ${g.en} / ${g.hi}'),
          for (final it in g.items) _row(it.en, it.hi, d.done.contains(it.id), () => _toggle(it.id)),
        ],
        _header('✍️ My own items / मेरे अपने आइटम'),
        for (final c in d.custom) _row(c.text, null, c.done, () => _toggleCustom(c.id), onDelete: () => _deleteCustom(c.id)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add item / आइटम जोड़ें'),
          ),
        ),
      ],
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(title, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
    );
  }

  Widget _row(String en, String? hi, bool done, VoidCallback onTap, {VoidCallback? onDelete}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: done ? AppC.greenWash : AppC.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: done ? AppC.green : AppC.line),
        ),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AppC.green : AppC.text54, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en,
                    style: TextStyle(
                      color: AppC.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: AppC.text54,
                    ),
                  ),
                  if (hi != null) ...[
                    const SizedBox(height: 2),
                    Text(hi, style: TextStyle(color: AppC.text70, fontSize: 11.5, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete / हटाएँ',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: AppC.text54, size: 20),
                onPressed: onDelete,
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
