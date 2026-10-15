import 'package:flutter/material.dart';
import '../services/daily_quiz_service.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';
import 'quiz_session_screen.dart';

const _navy = Color(0xFF081136);
const _cardBg = Color(0xFF101D57);

/// Aaj ka Daily Quiz (5 sawal, PIB Current Affairs se, Hindi + English).
/// Quiz GitHub Action banata hai; app roz sirf 1 read se use padhta hai.
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
      if (!mounted) return;
      setState(() {
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

  Future<void> _start(DailyQuiz quiz) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizSessionScreen(
        title: 'Daily Quiz',
        questions: quiz.questions,
        bookmarkSource: 'Daily Quiz ${quiz.day}',
        onFinished: (answers) => StudyStore.recordDailyQuiz(day: quiz.day, questions: quiz.questions, answers: answers),
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
            child: EmptyView('Aaj ka quiz abhi tayyar nahi hai.\nRoz subah ~6 baje aata hai — thodi der baad kholo.\n\nआज का क्विज़ अभी तैयार नहीं है। रोज़ सुबह ~6 बजे आता है।'),
          ),
        ]),
      );
    }
    final doneToday = _done != null && _done!.day == quiz.day;
    final isOld = quiz.day != StudyStore.today();
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
                Text(isOld ? 'Kal ka Daily Quiz' : 'Aaj ka Daily Quiz',
                    style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 4),
                Text('${quiz.questions.length} sawal • PIB Current Affairs se • Hindi + English',
                    textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF101D57), fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (doneToday)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Ho gaya! Aapka score: ${_done!.score} / ${_done!.total}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),
          if (doneToday)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Dobara khel sakte ho — par score aur goal me sirf pehli baar gina jaata hai.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11.5)),
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _start(quiz),
            child: Text(doneToday ? 'Dobara khelo' : 'Quiz shuru karo'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Har jawab ke baad turant sahi/galat aur explanation dikhta hai. Galat sawal apne aap Mistake Notebook me save ho jaate hain.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
