import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../screens/calculators_screen.dart';
import '../screens/exam_checklist_screen.dart';
import '../screens/important_days_screen.dart';
import '../screens/notes_screen.dart';
import '../services/checklist_store.dart';
import '../services/notes_store.dart';

/// Home ka "More Tools" card: My Notes, Important Days, Calculators, Exam Checklist.
/// (Ready Reckoner chart Speed Maths screen ke andar hai, taaki do jaise tile na ho.)
/// Sab data phone me hai - Firestore se kuch nahi padhta / likhta.
class MoreToolsCard extends StatefulWidget {
  const MoreToolsCard({super.key});

  @override
  State<MoreToolsCard> createState() => _MoreToolsCardState();
}

class _MoreToolsCardState extends State<MoreToolsCard> {
  int _notes = 0;
  int _checkDone = 0;
  int _checkTotal = 0;

  @override
  void initState() {
    super.initState();
    NotesStore.changes.addListener(_reload);
    ChecklistStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    NotesStore.changes.removeListener(_reload);
    ChecklistStore.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final n = await NotesStore.count();
      final c = await ChecklistStore.counts();
      if (!mounted) return;
      setState(() {
        _notes = n;
        _checkDone = c[0];
        _checkTotal = c[1];
      });
    } catch (_) {
      // purani value dikhti rahegi
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {}); // Important Days tile ka "aaj" text taaza
  }

  @override
  Widget build(BuildContext context) {
    final notesSub = _notes == 0 ? 'Write & save\nलिखें और सेव करें' : '$_notes saved\n$_notes नोट सेव';
    final checkSub = _checkDone == 0 ? 'Admit card, ID, pens\nएडमिट कार्ड, ID, पेन' : '$_checkDone / $_checkTotal ready\n$_checkDone / $_checkTotal तैयार';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppC.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppC.tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✨ More Tools / और टूल्स', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('📝', 'My Notes', notesSub, () => _open(const NotesScreen())),
              const SizedBox(width: 10),
              _tile('📅', 'Important Days', '${importantDayTileText()}\nमहत्वपूर्ण दिवस', () => _open(const ImportantDaysScreen())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile('🧮', 'Calculators', '35+ tools • Marks • GST\n35+ टूल • अंक • GST', () => _open(const CalculatorsScreen())),
              const SizedBox(width: 10),
              _tile('✅', 'Exam Checklist', checkSub, () => _open(const ExamChecklistScreen())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(String emoji, String title, String sub, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 78,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, maxLines: 1, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppC.text70, fontSize: 10.5, height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
