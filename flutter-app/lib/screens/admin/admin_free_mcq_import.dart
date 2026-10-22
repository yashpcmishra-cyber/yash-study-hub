import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../models/models.dart';
import '../../services/free_mcq_service.dart';
import '../../services/mcq_bulk_parser.dart' show kMaxQuestionsPerTest;

/// What the admin picked in the "Copy from Free MCQs" sheet.
class FreeMcqImportResult {
  final List<MockQuestion> questions;
  final int setCount;

  /// "Static GK - October 2026" when exactly one set was picked, else ''.
  final String suggestedTitle;

  /// The subject name when every picked set has the same subject, else ''.
  final String suggestedSubject;

  const FreeMcqImportResult({
    required this.questions,
    required this.setCount,
    required this.suggestedTitle,
    required this.suggestedSubject,
  });
}

/// Admin only: choose any Free MCQs set(s) (any exam, subject and month) and
/// copy all their questions (English + Hindi + explanation) into a mock test.
/// Returns null if the admin closes the sheet without copying.
Future<FreeMcqImportResult?> showFreeMcqImportSheet(BuildContext context) {
  return showModalBottomSheet<FreeMcqImportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppC.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => const _FreeMcqImportSheet(),
  );
}

class _FreeMcqImportSheet extends StatefulWidget {
  const _FreeMcqImportSheet();

  @override
  State<_FreeMcqImportSheet> createState() => _FreeMcqImportSheetState();
}

class _FreeMcqImportSheetState extends State<_FreeMcqImportSheet> {
  final _svc = FreeMcqService();
  // force: the admin always sees the newest sets (1 document read).
  late final Future<FreeMcqIndex?> _index = _svc.loadIndex(force: true);
  final Set<String> _picked = <String>{};
  bool _copying = false;
  String? _error;

  String _subjectName(FreeMcqIndex index, String id) {
    for (final s in index.subjects) {
      if (s.id == id) return s.name;
    }
    return id;
  }

  /// This exam's sets: newest month first, then in the usual subject order.
  List<FreeMcqSetMeta> _setsOf(FreeMcqIndex index, String examId) {
    int order(String subjectId) {
      final i = index.subjects.indexWhere((s) => s.id == subjectId);
      return i < 0 ? 999 : i;
    }

    final list = index.sets.where((s) => s.examId == examId).toList();
    list.sort((a, b) {
      final byMonth = b.monthKey.compareTo(a.monthKey);
      return byMonth != 0 ? byMonth : order(a.subjectId).compareTo(order(b.subjectId));
    });
    return list;
  }

  int _pickedQuestionCount(FreeMcqIndex index) {
    var n = 0;
    for (final s in index.sets) {
      if (_picked.contains(s.id)) n += s.count;
    }
    return n;
  }

  Future<void> _copy(FreeMcqIndex index) async {
    if (_copying || _picked.isEmpty) return;
    setState(() {
      _copying = true;
      _error = null;
    });
    try {
      final chosen = index.sets.where((s) => _picked.contains(s.id)).toList();
      final questions = <MockQuestion>[];
      for (final meta in chosen) {
        // One Firestore read per set (then cached on this phone).
        final set = await _svc.loadSet(meta);
        questions.addAll(set.questions);
      }
      final subjectIds = chosen.map((s) => s.subjectId).toSet();
      final subject = subjectIds.length == 1 ? _subjectName(index, subjectIds.first) : '';
      final title = chosen.length == 1
          ? '${_subjectName(index, chosen.first.subjectId)} - ${FreeMcqService.monthLabel(chosen.first.monthKey)}'
          : '';
      if (!mounted) return;
      Navigator.of(context).pop(
        FreeMcqImportResult(
          questions: questions,
          setCount: chosen.length,
          suggestedTitle: title,
          suggestedSubject: subject,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _copying = false;
        _error = 'Could not copy these sets. Check your internet and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: FutureBuilder<FreeMcqIndex?>(
          future: _index,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final index = snap.data;
            if (snap.hasError || index == null || index.sets.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    snap.hasError ? 'Could not load the Free MCQs list: ${snap.error}' : 'No Free MCQs set has been created yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppC.muted),
                  ),
                ),
              );
            }

            final total = _pickedQuestionCount(index);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Copy from Free MCQs', style: TextStyle(color: AppC.text, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tick one or more sets (any exam, subject or month). All their questions are added to the test you are building.',
                      style: TextStyle(color: AppC.muted, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final exam in index.exams)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text('${exam.emoji} ${exam.name}', style: TextStyle(color: AppC.text, fontSize: 14)),
                            iconColor: AppC.muted,
                            collapsedIconColor: AppC.muted,
                            children: [
                              for (final s in _setsOf(index, exam.id))
                                CheckboxListTile(
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: AppC.accent,
                                  value: _picked.contains(s.id),
                                  onChanged: _copying
                                      ? null
                                      : (v) => setState(() {
                                            if (v == true) {
                                              _picked.add(s.id);
                                            } else {
                                              _picked.remove(s.id);
                                            }
                                          }),
                                  title: Text(
                                    '${_subjectName(index, s.subjectId)} · ${FreeMcqService.monthLabel(s.monthKey)}',
                                    style: TextStyle(color: AppC.text, fontSize: 13),
                                  ),
                                  subtitle: Text('${s.count} MCQs', style: TextStyle(color: AppC.muted, fontSize: 11)),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (total > kMaxQuestionsPerTest)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'One test can have at most $kMaxQuestionsPerTest questions. Tick fewer sets.',
                            style: TextStyle(color: AppC.orange, fontSize: 12),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(_error!, style: TextStyle(color: AppC.orange, fontSize: 12)),
                        ),
                      ElevatedButton(
                        onPressed: (_picked.isEmpty || _copying || total > kMaxQuestionsPerTest) ? null : () => _copy(index),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
                        child: _copying
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_picked.isEmpty ? 'Tick a set to copy' : 'Copy ${_picked.length} set(s) · $total MCQs'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
