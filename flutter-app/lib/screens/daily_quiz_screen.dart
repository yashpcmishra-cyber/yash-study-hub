import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/daily_quiz_service.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';
import 'quiz_session_screen.dart';

import '../app_colors.dart';

/// Today's Daily Quiz (up to 10 questions/day, capped by the Daily goal, from PIB Current Affairs, Hindi + English).
/// The quiz is created by a GitHub Action; the app reads it with just 1 read per day.
class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  final _svc = DailyQuizService();
  DailyQuiz? _quiz;
  QuizDone? _done;
  Object? _error;
  bool _loading = true;
  int _count = StudyStore.defaultGoal; // quiz shows min(Daily goal, questions available) - quiz has at most 10

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = await _svc.load(force: force);
      final d = await StudyStore.quizDone();
      final g = await StudyStore.goalTarget();
      if (!mounted) return;
      setState(() {
        _count = g;
        _quiz = q;
        _done = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _start(DailyQuiz quiz, List<MockQuestion> qs) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: 'Daily Quiz',
        questions: qs,
        bookmarkSource: 'Daily Quiz ${quiz.day}',
        onFinished: (answers) => StudyStore.recordDailyQuiz(day: quiz.day, questions: qs, answers: answers),
      ),
    ));
    final d = await StudyStore.quizDone();
    if (mounted) setState(() => _done = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Quiz')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null && _quiz == null) {
      return RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(children: [SizedBox(height: 400, child: ErrorView(error: _error))]),
      );
    }
    final quiz = _quiz;
    if (quiz == null) {
      return RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(children: const [
          SizedBox(
            height: 400,
            child: EmptyView('Today\u2019s quiz is not ready yet.\nPlease check back a little later.\n\nआज का क्विज़ अभी तैयार नहीं है।\nकृपया थोड़ी देर बाद देखें।'),
          ),
        ]),
      );
    }
    final doneToday = _done != null && _done!.day == quiz.day;
    final isOld = quiz.day != StudyStore.today();
    final qs = quiz.questions.take(_count).toList();
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('🧠', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(isOld ? 'Yesterday\u2019s Daily Quiz / कल का डेली क्विज़' : 'Today\u2019s Daily Quiz / आज का डेली क्विज़',
                    style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 4),
                Text('${qs.length} questions • from PIB Current Affairs • Hindi + English\n${qs.length} सवाल • PIB करेंट अफेयर्स से • हिंदी + अंग्रेज़ी',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (doneToday)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppC.card2, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Done! Your score / पूरा हुआ! आपका स्कोर: ${_done!.score} / ${_done!.total}',
                        style: TextStyle(color: AppC.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),
          if (doneToday)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('You can play again \u2014 but only the first attempt counts for score and goal.\nआप दोबारा खेल सकते हैं \u2014 पर स्कोर और गोल में केवल पहला प्रयास गिना जाता है।',
                  textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5)),
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _start(quiz, qs),
            child: Text(doneToday ? 'Play again / दोबारा खेलें' : 'Start quiz / क्विज़ शुरू करें'),
          ),
          const SizedBox(height: 14),
          Text(
            'After every answer you instantly see right/wrong and the explanation. Wrong questions are saved to the Mistake Notebook automatically.\nहर जवाब के बाद सही/गलत और व्याख्या तुरंत दिखती है। गलत सवाल अपने आप Mistake Notebook में सेव हो जाते हैं।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            'Daily Quiz has up to 10 questions a day. Complete the rest of your Daily goal with Mock Tests.\nडेली क्विज़ में रोज़ अधिकतम 10 सवाल होते हैं। बाकी Daily goal Mock Tests से पूरा करें।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
