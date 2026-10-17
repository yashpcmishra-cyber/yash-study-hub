import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/daily_quiz_service.dart';
import '../services/study_store.dart';
import '../widgets/state_views.dart';
import 'quiz_session_screen.dart';

import '../app_colors.dart';

/// Daily Quiz of the last 7 days (up to 10 questions/day, capped by the Daily goal, from PIB Current Affairs, Hindi + English).
/// The quizzes are created by a GitHub Action; the app reads each day with just 1 read.
/// On the 8th day an old quiz is deleted from Firebase and from this phone's cache.
class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final _svc = DailyQuizService();
  final List<String> _days = StudyStore.quizDayKeys(); // aaj pehle, phir pichhle 6 din (yyyy-MM-dd)
  int _dayIndex = 0;
  Set<String> _doneDays = <String>{};
  String? _note;
  DailyQuiz? _quiz;
  QuizDone? _done;
  Object? _error;
  bool _loading = true;
  int _req = 0; // sabse naya chip-tap hi jeete (dheemi purani request ignore)
  int _count = StudyStore.defaultGoal; // quiz shows min(Daily goal, questions available) - quiz has at most 10

  @override
  void initState() {
    super.initState();
    _init();
  }

  String _dayLabel(int i) {
    if (i == 0) return 'Today';
    if (i == 1) return 'Yesterday';
    final p = _days[i].split('-');
    return '${p[2]} ${_months[int.parse(p[1]) - 1]}';
  }

  /// Phone se 7 din se purana quiz hatao, phir aaj ka quiz kholo
  /// (aaj ka na ho to pichhle 2 din me se jo pehle mile).
  Future<void> _init() async {
    final my = ++_req;
    await StudyStore.purgeOldQuizData();
    Object? firstError;
    for (var i = 0; i < 3; i++) {
      try {
        final q = await _svc.loadDay(_days[i]);
        if (my != _req) return;
        if (q != null) {
          await _show(i, q, auto: i > 0);
          return;
        }
      } catch (e) {
        firstError ??= e;
        break;
      }
    }
    final done = await StudyStore.quizDoneDays();
    if (!mounted || my != _req) return;
    setState(() {
      _doneDays = done;
      _dayIndex = 0;
      _quiz = null;
      _done = null;
      _error = firstError;
      _loading = false;
    });
  }

  Future<void> _show(int i, DailyQuiz? q, {bool auto = false}) async {
    final d = await StudyStore.quizDoneFor(_days[i]);
    final doneDays = await StudyStore.quizDoneDays();
    final g = await StudyStore.goalTarget();
    if (!mounted) return;
    setState(() {
      _dayIndex = i;
      _count = g;
      _quiz = q;
      _done = d;
      _doneDays = doneDays;
      _note = auto
          ? 'Today\u2019s quiz is not ready yet \u2014 showing ${_dayLabel(i)} / आज का क्विज़ अभी तैयार नहीं है \u2014 ${_dayLabel(i)} का दिखा रहे हैं'
          : null;
      _error = null;
      _loading = false;
    });
  }

  Future<void> _select(int i, {bool force = false}) async {
    final my = ++_req;
    setState(() {
      _dayIndex = i;
      _loading = true;
      _error = null;
      _note = null;
    });
    try {
      final q = await _svc.loadDay(_days[i], force: force);
      if (my != _req) return;
      await _show(i, q);
    } catch (e) {
      if (!mounted || my != _req) return;
      setState(() {
        _quiz = null;
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
    final d = await StudyStore.quizDoneFor(quiz.day);
    final doneDays = await StudyStore.quizDoneDays();
    if (mounted) {
      setState(() {
        _done = d;
        _doneDays = doneDays;
      });
    }
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppC.gold : AppC.cardA60,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? AppC.accent : AppC.glass33),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? AppC.onGold : AppC.text,
              fontSize: 12,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayChips() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        itemCount: _days.length,
        itemBuilder: (context, i) {
          final tick = _doneDays.contains(_days[i]) ? ' \u2713' : '';
          return _chip('${_dayLabel(i)}$tick', i == _dayIndex, () {
            if (i != _dayIndex) _select(i);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Quiz')),
      body: Column(
        children: [
          _dayChips(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  String _headline() {
    if (_dayIndex == 0) return 'Today\u2019s Daily Quiz / आज का डेली क्विज़';
    if (_dayIndex == 1) return 'Yesterday\u2019s Daily Quiz / कल का डेली क्विज़';
    return '${_dayLabel(_dayIndex)} Daily Quiz / ${_dayLabel(_dayIndex)} का डेली क्विज़';
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null && _quiz == null) {
      return RefreshIndicator(
        onRefresh: () => _select(_dayIndex, force: true),
        child: ListView(children: [SizedBox(height: 400, child: ErrorView(error: _error))]),
      );
    }
    final quiz = _quiz;
    if (quiz == null) {
      return RefreshIndicator(
        onRefresh: () => _select(_dayIndex, force: true),
        child: ListView(children: [
          SizedBox(
            height: 400,
            child: _dayIndex == 0
                ? const EmptyView('Today\u2019s quiz is not ready yet.\nPlease check back a little later.\n\nआज का क्विज़ अभी तैयार नहीं है।\nकृपया थोड़ी देर बाद देखें।')
                : const EmptyView('No quiz is available for this day.\n\nइस दिन का क्विज़ उपलब्ध नहीं है।'),
          ),
        ]),
      );
    }
    final doneToday = _done != null && _done!.day == quiz.day;
    final qs = quiz.questions.take(_count).toList();
    return RefreshIndicator(
      onRefresh: () => _select(_dayIndex, force: true),
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
                Text(_headline(),
                    style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 4),
                Text('${qs.length} questions • from PIB Current Affairs • Hindi + English\n${qs.length} सवाल • PIB करेंट अफेयर्स से • हिंदी + अंग्रेज़ी',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 12.5)),
              ],
            ),
          ),
          if (_note != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_note!, textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.4)),
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
          const SizedBox(height: 10),
          Text(
            'Quizzes of the last 7 days stay available. Older ones are removed automatically.\nपिछले 7 दिनों के क्विज़ उपलब्ध रहते हैं। उससे पुराने अपने आप हट जाते हैं।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
