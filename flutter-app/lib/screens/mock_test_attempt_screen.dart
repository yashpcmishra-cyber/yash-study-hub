import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/mock_rank_service.dart';
import 'mock_test_scorecard_screen.dart';
import '../widgets/space_background.dart';
import '../widgets/di_image.dart';

import '../app_colors.dart';

/// Exam-style screen: ek screen par ek question, upar countdown timer,
/// neeche Previous / Clear / Next. Answer submit ke baad hi dikhte hain.
/// Purane tests (bina time / Hindi) bhi chalte hain: timer ki jagah elapsed
/// time dikhta hai aur Hindi toggle chhup jata hai.
class MockTestAttemptScreen extends StatefulWidget {
  final MockTestModel test;
  const MockTestAttemptScreen({super.key, required this.test});

  @override
  State<MockTestAttemptScreen> createState() => _MockTestAttemptScreenState();
}

class _MockTestAttemptScreenState extends State<MockTestAttemptScreen> {
  late final List<int?> _answers;
  late final bool _timed;
  late final bool _hasHindi;
  late final DateTime _startedAt;
  final _fs = FirestoreService();
  final _identityController = TextEditingController();
  Timer? _ticker;

  int _index = 0;
  bool _hindi = false;
  bool _submitting = false;
  int _secondsShown = 0; // timed: bacha hua time, untimed: beeta hua time

  @override
  void initState() {
    super.initState();
    Future.microtask(() => spaceBackgroundPause.value++);
    _answers = List<int?>.filled(widget.test.questions.length, null);
    _timed = widget.test.durationMinutes > 0;
    _hasHindi = mockHasHindi(widget.test);
    _startedAt = DateTime.now();
    _secondsShown = _timed ? widget.test.durationMinutes * 60 : 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _identityController.dispose();
    Future.microtask(() => spaceBackgroundPause.value--);
    super.dispose();
  }

  int get _elapsed => DateTime.now().difference(_startedAt).inSeconds;

  // Time system clock se nikalta hai, isliye app background me jaye tab bhi
  // timer sahi rehta hai.
  void _tick() {
    if (!mounted || _submitting) return;
    if (_timed) {
      final left = widget.test.durationMinutes * 60 - _elapsed;
      if (left <= 0) {
        setState(() => _secondsShown = 0);
        _submit(auto: true);
        return;
      }
      setState(() => _secondsShown = left);
    } else {
      setState(() => _secondsShown = _elapsed);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Leave the test?', style: TextStyle(color: AppC.text)),
        content: Text('Your answers will be lost.', style: TextStyle(color: AppC.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) {
      _ticker?.cancel();
      Navigator.of(context).pop();
    }
  }

  void _openPalette() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppC.card,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jump to question', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Green = answered', style: TextStyle(color: AppC.muted, fontSize: 11)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_answers.length, (i) {
                      final answered = _answers[i] != null;
                      final current = i == _index;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() => _index = i);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: answered ? Colors.green.shade700 : AppC.card2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: current ? AppC.accent : AppC.text24, width: current ? 2 : 1),
                          ),
                          child: Text('${i + 1}', style: TextStyle(color: answered ? Colors.white : AppC.text, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // auto = true: time khatam, bina poochhe submit.
  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;

    final prefs = await SharedPreferences.getInstance();
    if (_submitting || !mounted) return;
    final savedIdentity = (prefs.getString('student_email') ?? prefs.getString('attempt_identity') ?? '').trim();

    if (auto) {
      setState(() => _submitting = true);
      // Koi dialog / bottom sheet khula ho to band karo.
      Navigator.of(context, rootNavigator: true).popUntil((r) => r is! PopupRoute);
    } else {
      final unanswered = _answers.where((a) => a == null).length;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppC.card,
          title: Text('Submit the test?', style: TextStyle(color: AppC.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unanswered > 0
                    ? '$unanswered questions are still unanswered. You can\u2019t go back after submitting.'
                    : 'You can\u2019t go back after submitting. Please confirm.',
                style: TextStyle(color: AppC.muted),
              ),
              if (savedIdentity.isEmpty) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _identityController,
                  style: TextStyle(color: AppC.text),
                  decoration: const InputDecoration(
                    labelText: 'Your name or email (optional)',
                    helperText: 'So your teacher can see your score',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
          ],
        ),
      );
      // Dialog ke dauran timer khatam ho gaya to auto-submit pehle hi chal chuka hai.
      if (proceed != true || _submitting || !mounted) return;
      setState(() => _submitting = true);
    }

    _ticker?.cancel();
    final r = MockResult.compute(widget.test, _answers);
    var timeTaken = _elapsed;
    if (_timed && timeTaken > widget.test.durationMinutes * 60) timeTaken = widget.test.durationMinutes * 60;

    var identity = savedIdentity;
    if (identity.isEmpty) {
      identity = _identityController.text.trim();
      if (identity.isNotEmpty) {
        try {
          await prefs.setString('attempt_identity', identity);
        } catch (_) {
          // not important
        }
      }
    }
    if (identity.isEmpty) identity = 'anonymous';
    // The profile name saved at login (empty if the student never logged in). It lets the teacher see WHO attempted.
    final studentName = (prefs.getString('student_name') ?? '').trim();

    // Teacher ke liye score save karna student ka result kabhi nahi rokta.
    String? note;
    try {
      await _fs
          .saveMockAttempt(
            studentEmail: identity,
            mockTestId: widget.test.id,
            mockTestTitle: widget.test.title,
            score: r.correct,
            total: widget.test.questions.length,
            answers: _answers,
            studentName: studentName,
            subject: widget.test.subject,
            folderId: widget.test.folderId,
          )
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      note = 'You seem to be offline \u2014 your score will be sent to your teacher automatically when you are back online.';
    } catch (_) {
      note = 'Your score could not be sent to your teacher this time.';
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MockTestScorecardScreen(
        test: widget.test,
        answers: List<int?>.from(_answers),
        timeTakenSec: timeTaken,
        autoSubmitted: auto,
        note: note,
      ),
    ));
  }

  void _goNextOrSubmit() {
    if (_index >= widget.test.questions.length - 1) {
      _submit();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    final total = test.questions.length;
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppC.bg,
        appBar: AppBar(
          // Landscape: slim bar that also carries the timer + language toggle,
          // so the separate header row is not needed and more screen is left.
          toolbarHeight: land ? 44 : null,
          titleSpacing: land ? 0 : null,
          title: land && total > 0
              ? Row(
                  children: [
                    Flexible(child: Text(test.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
                    const SizedBox(width: 14),
                    _timerRow(onBar: true),
                  ],
                )
              : Text(test.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (land && total > 0 && _hasHindi) ...[_langToggle(onBar: true), const SizedBox(width: 4)],
            if (total > 0) IconButton(tooltip: 'Questions', icon: const Icon(Icons.grid_view_rounded), onPressed: _openPalette),
            TextButton(onPressed: _submitting ? null : () => _submit(), child: const Text('Submit')),
          ],
        ),
        body: total == 0
            ? Center(child: Text('This test has no questions yet', style: TextStyle(color: AppC.muted)))
            : (land ? _landscapeBody(total) : _body(total)),
      ),
    );
  }

  Widget _body(int total) {
    final q = widget.test.questions[_index];
    final opts = mockOptions(q, _hindi);
    return Column(
      children: [
        _header(total),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _passageBox(q),
                Text(mockText(q, _hindi), style: TextStyle(color: AppC.text, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 16),
                for (var oi = 0; oi < opts.length; oi++) _optionTile(oi, opts[oi]),
              ],
            ),
          ),
        ),
        _bottomBar(total),
      ],
    );
  }

  // Reasoning: Directions / puzzle information shared by a group of questions.
  // Nothing is shown for other subjects (their questions have no passage).
  Widget _passageBox(MockQuestion q, {bool compact = false}) {
    final p = mockPassage(q, _hindi);
    final img = q.passageImage.trim();
    if (p.isEmpty && img.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.text12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.isNotEmpty) Text(p, style: TextStyle(color: AppC.text70, fontSize: compact ? 12.5 : 14, height: 1.4)),
          if (img.isNotEmpty) Padding(padding: EdgeInsets.only(top: p.isNotEmpty ? 8 : 0), child: DiImage(url: img)),
        ],
      ),
    );
  }

  String _marksLine(int total) {
    final t = widget.test;
    return 'Q ${_index + 1}/$total  \u2022  +${fmtMarks(t.marksPerQuestion)}'
        '${t.negativeMarks > 0 ? '  /  \u2212${fmtMarks(t.negativeMarks)}' : ''}';
  }

  Widget _timerRow({bool onBar = false}) {
    final lowTime = _timed && _secondsShown <= 60;
    // Top bar (landscape) light theme me navy hoti hai, isliye wahan safed/yellow.
    final cText = onBar ? Colors.white : AppC.text;
    final cAccent = onBar ? const Color(0xFFFFFF29) : AppC.accent;
    final cRed = onBar ? Colors.redAccent : AppC.red;
    final cMuted = onBar ? Colors.grey : AppC.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 18, color: lowTime ? cRed : cAccent),
        const SizedBox(width: 4),
        Text(
          fmtDuration(_secondsShown),
          style: TextStyle(color: lowTime ? cRed : cText, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (!_timed) Text('  (no limit)', style: TextStyle(color: cMuted, fontSize: 11)),
      ],
    );
  }

  Widget _langToggle({bool onBar = false}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: onBar ? Colors.white24 : AppC.text24), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langBtn('EN', !_hindi, () => setState(() => _hindi = false), onBar: onBar),
          _langBtn('\u0939\u093f\u0902', _hindi, () => setState(() => _hindi = true), onBar: onBar),
        ],
      ),
    );
  }

  /// Landscape layout: question on the left, options on the right (each side
  /// scrolls on its own), slim bottom bar. Whole question + options fit on
  /// one screen without wasting the top half.
  Widget _landscapeBody(int total) {
    final q = widget.test.questions[_index];
    final opts = mockOptions(q, _hindi);
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_marksLine(total), style: TextStyle(color: AppC.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        _passageBox(q, compact: true),
                        Text(mockText(q, _hindi), style: TextStyle(color: AppC.text, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: AppC.text12),
                Expanded(
                  flex: 10,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                    child: Column(
                      children: [
                        for (var oi = 0; oi < opts.length; oi++) _optionTile(oi, opts[oi], compact: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _bottomBar(total, compact: true),
      ],
    );
  }

  Widget _header(int total) {
    final lowTime = _timed && _secondsShown <= 60;
    final marksLine = _marksLine(total);
    return Container(
      color: AppC.card2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.timer_outlined, size: 18, color: lowTime ? AppC.red : AppC.accent),
                  const SizedBox(width: 4),
                  Text(
                    fmtDuration(_secondsShown),
                    style: TextStyle(color: lowTime ? AppC.red : AppC.text, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  if (!_timed) Text('  (no limit)', style: TextStyle(color: AppC.muted, fontSize: 11)),
                ]),
                const SizedBox(height: 2),
                Text(marksLine, style: TextStyle(color: AppC.muted, fontSize: 12)),
              ],
            ),
          ),
          if (_hasHindi) _langToggle(),
        ],
      ),
    );
  }

  Widget _langBtn(String label, bool active, VoidCallback onTap, {bool onBar = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: active ? AppC.gold : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: active ? AppC.onGold : (onBar ? Colors.white70 : AppC.text70), fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _optionTile(int oi, String text, {bool compact = false}) {
    final selected = _answers[_index] == oi;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: GestureDetector(
        onTap: () => setState(() => _answers[_index] = oi),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            color: selected ? AppC.goldWash2 : AppC.card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppC.accent : AppC.text24, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppC.gold : Colors.transparent,
                  border: Border.all(color: selected ? AppC.accent : AppC.text54),
                ),
                child: Text(
                  String.fromCharCode(65 + oi),
                  style: TextStyle(color: selected ? AppC.onGold : AppC.text70, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: AppC.text, fontSize: 14, height: 1.3))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(int total, {bool compact = false}) {
    final last = _index >= total - 1;
    final pad = EdgeInsets.symmetric(horizontal: 4, vertical: compact ? 6 : 12);
    return SafeArea(
      top: false,
      child: Container(
        color: AppC.card2,
        padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 12, compact ? 4 : 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: pad),
                onPressed: _index > 0 ? () => setState(() => _index--) : null,
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: pad),
                onPressed: _answers[_index] != null ? () => setState(() => _answers[_index] = null) : null,
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: pad),
                onPressed: _submitting ? null : _goNextOrSubmit,
                child: Text(last ? 'Submit' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
