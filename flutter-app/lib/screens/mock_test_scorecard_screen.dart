import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';

class MockTestScorecardScreen extends StatelessWidget {
  final MockTestModel test;
  final List<int?> answers;
  final int score;
  final String? note; // e.g. "you are offline — score will be sent later"
  const MockTestScorecardScreen({super.key, required this.test, required this.answers, required this.score, this.note});

  @override
  Widget build(BuildContext context) {
    final total = test.questions.length;
    final percent = total == 0 ? 0 : ((score / total) * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Scorecard'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(test.title, style: const TextStyle(color: Color(0xFF081136), fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Text('$score / $total', style: const TextStyle(color: Color(0xFF081136), fontWeight: FontWeight.bold, fontSize: 32)),
                Text('$percent%', style: const TextStyle(color: Color(0xFF101D57), fontSize: 14)),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          const Text('Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...List.generate(total, (i) {
            final q = test.questions[i];
            final given = answers[i];
            final correct = q.correctIndex;
            final isCorrect = given == correct;
            // Safe even if the saved question data is incomplete.
            final correctText = (correct >= 0 && correct < q.options.length) ? q.options[correct] : 'Not available';
            final givenText = (given != null && given >= 0 && given < q.options.length) ? q.options[given] : '';
            return DepthCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(isCorrect ? '✅' : '❌', style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${i + 1}. ${q.text}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                    ]),
                    const SizedBox(height: 6),
                    Text('Correct answer: $correctText', style: const TextStyle(color: Colors.green, fontSize: 12)),
                    if (given != null && !isCorrect) Text('Your answer: $givenText', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    if (given == null) const Text('Not attempted', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Back to Home')),
        ],
      ),
    );
  }
}
