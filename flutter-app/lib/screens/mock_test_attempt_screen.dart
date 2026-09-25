import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../widgets/depth_card.dart';
import 'mock_test_scorecard_screen.dart';

/// Students attempt the WHOLE test first — no answer is checked or shown
/// until they press "Submit Test" at the very end, exactly as requested.
class MockTestAttemptScreen extends StatefulWidget {
  final MockTestModel test;
  const MockTestAttemptScreen({super.key, required this.test});

  @override
  State<MockTestAttemptScreen> createState() => _MockTestAttemptScreenState();
}

class _MockTestAttemptScreenState extends State<MockTestAttemptScreen> {
  late List<int?> _answers;
  final _fs = FirestoreService();
  final _identityController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(widget.test.questions.length, null);
  }

  @override
  void dispose() {
    _identityController.dispose();
    super.dispose();
  }

  // Asked when the student presses the Back button in the middle of a test,
  // so answers are not lost by accident.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF081136),
        title: const Text('Leave the test?', style: TextStyle(color: Colors.white)),
        content: const Text('Your answers will be lost.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmSubmit() async {
    if (_submitting) return;
    final prefs = await SharedPreferences.getInstance();
    // Who is taking the test: the email used for a batch (if any), or a
    // name/email typed here once. Optional — "anonymous" if left empty.
    final savedIdentity = (prefs.getString('student_email') ?? prefs.getString('attempt_identity') ?? '').trim();
    final askIdentity = savedIdentity.isEmpty;

    final unanswered = _answers.where((a) => a == null).length;
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF081136),
        title: const Text('Submit the test?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unanswered > 0
                  ? '$unanswered questions are still unanswered. You can\u2019t go back after submitting.'
                  : 'You can\u2019t go back after submitting. Please confirm.',
              style: const TextStyle(color: Colors.grey),
            ),
            if (askIdentity) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _identityController,
                style: const TextStyle(color: Colors.white),
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
    if (proceed != true) return;

    setState(() => _submitting = true);

    int score = 0;
    for (var i = 0; i < widget.test.questions.length; i++) {
      if (_answers[i] != null && _answers[i] == widget.test.questions[i].correctIndex) score++;
    }

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

    // Saving the score for the teacher must NEVER block the student from
    // seeing their own result. Offline, Firestore keeps the write and sends
    // it automatically later, so a timeout is fine.
    String? note;
    try {
      await _fs
          .saveMockAttempt(
            studentEmail: identity,
            mockTestId: widget.test.id,
            mockTestTitle: widget.test.title,
            score: score,
            total: widget.test.questions.length,
            answers: _answers,
          )
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      note = 'You seem to be offline \u2014 your score will be sent to your teacher automatically when you are back online.';
    } catch (_) {
      note = 'Your score could not be sent to your teacher this time.';
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MockTestScorecardScreen(test: widget.test, answers: _answers, score: score, note: note),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.test.title)),
        body: ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: widget.test.questions.length + 1,
          itemBuilder: (context, i) {
            if (i == widget.test.questions.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ElevatedButton(
                  onPressed: _submitting ? null : _confirmSubmit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit Test'),
                ),
              );
            }
            final q = widget.test.questions[i];
            return DepthCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${q.text}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...List.generate(q.options.length, (oi) => RadioListTile<int>(
                          dense: true,
                          activeColor: const Color(0xFFFFFF29),
                          title: Text(q.options[oi], style: const TextStyle(color: Colors.white, fontSize: 13)),
                          value: oi,
                          groupValue: _answers[i],
                          onChanged: (v) => setState(() => _answers[i] = v),
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
