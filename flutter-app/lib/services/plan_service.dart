import 'revision_store.dart';
import 'speed_math_store.dart';
import 'study_store.dart';
import 'study_time_store.dart';
import 'syllabus_store.dart';

// =============================================================================
//  PlanService - "Aaj ka Plan". Phone me jo data pehle se hai (quiz, revision,
//  goal, study timer, syllabus, speed maths) usi se aaj ke kaam banata hai aur
//  batata hai kaun-sa ho gaya. Kuch bhi alag save nahi hota, aur Firestore ko
//  0 reads / 0 writes.
// =============================================================================

class PlanTask {
  final String id; // quiz | revision | goal | focus | syllabus | speed
  final String emoji;
  final String title;
  final String titleHi;
  final String sub;
  final String subHi;
  final bool done;
  const PlanTask({
    required this.id,
    required this.emoji,
    required this.title,
    required this.titleHi,
    required this.sub,
    required this.subHi,
    required this.done,
  });
}

class PlanSummary {
  final List<PlanTask> tasks;
  final int daysLeft; // exam me kitne din (-1 = exam date nahi daali / nikal gayi)
  final String examName;
  final int focusTargetMin;
  const PlanSummary(this.tasks, this.daysLeft, this.examName, this.focusTargetMin);

  int get total => tasks.length;
  int get doneCount => tasks.where((t) => t.done).length;
  double get ratio => total == 0 ? 0.0 : doneCount / total;
  bool get complete => total > 0 && doneCount >= total;
}

class PlanService {
  PlanService._();

  /// Exam jitna paas, padhai ka target utna zyada.
  static int focusTargetMinutes(int daysLeft) {
    if (daysLeft >= 0 && daysLeft <= 30) return 120;
    if (daysLeft > 30 && daysLeft <= 90) return 90;
    return 60;
  }

  static Future<PlanSummary> build() async {
    final today = StudyStore.today();

    final quiz = await StudyStore.quizDone();
    final quizDone = quiz != null && quiz.day == today;
    final rev = await RevisionStore.overview();
    final goalTarget = await StudyStore.goalTarget();
    final goalDone = await StudyStore.goalDoneToday();
    final focusSec = await StudyTimeStore.secondsOn(today);
    final exam = await StudyStore.readExam();
    final daysLeft = (exam.isSet && exam.daysLeft() >= 0) ? exam.daysLeft() : -1;
    final focusMin = focusTargetMinutes(daysLeft);
    final sylExam = await SyllabusStore.selectedExam();
    final doneMap = await SyllabusStore.doneMap();
    final sylToday = doneMap.values.where((d) => d == today).length;
    final speedToday = await SpeedMathStore.roundsOn(today);

    final tasks = <PlanTask>[
      PlanTask(
        id: 'quiz',
        emoji: '🧠',
        title: 'Daily Quiz',
        titleHi: 'डेली क्विज़',
        sub: quizDone ? 'Completed ✓' : "Play today's current affairs quiz",
        subHi: quizDone ? 'पूरा ✓' : 'आज का करेंट अफेयर्स क्विज़ खेलें',
        done: quizDone,
      ),
    ];

    if (rev.total > 0) {
      final due = rev.due;
      tasks.add(PlanTask(
        id: 'revision',
        emoji: '🔁',
        title: 'Smart Revision',
        titleHi: 'स्मार्ट रिवीज़न',
        sub: due > 0 ? '$due questions due today' : 'All revised ✓',
        subHi: due > 0 ? 'आज $due सवाल बाकी' : 'सब हो गया ✓',
        done: due == 0,
      ));
    }

    tasks.add(PlanTask(
      id: 'goal',
      emoji: '🎯',
      title: 'Daily Goal: $goalTarget questions',
      titleHi: 'डेली गोल: $goalTarget सवाल',
      sub: '$goalDone / $goalTarget done (Mock tests or Free MCQs)',
      subHi: '$goalDone / $goalTarget पूरे (मॉक टेस्ट या फ्री MCQ)',
      done: goalDone >= goalTarget,
    ));

    tasks.add(PlanTask(
      id: 'focus',
      emoji: '⏱️',
      title: 'Focus Time: $focusMin min',
      titleHi: 'फोकस टाइम: $focusMin मिनट',
      sub: 'Studied ${StudyTimeStore.fmt(focusSec)} today (Study Timer)',
      subHi: 'आज ${StudyTimeStore.fmt(focusSec)} पढ़ाई की (स्टडी टाइमर)',
      done: focusSec >= focusMin * 60,
    ));

    if (sylExam == null) {
      tasks.add(const PlanTask(
        id: 'syllabus',
        emoji: '📚',
        title: 'Pick your exam syllabus',
        titleHi: 'अपना सिलेबस चुनें',
        sub: 'Track topics and get a weekly plan',
        subHi: 'टॉपिक ट्रैक करें और हफ़्ते की योजना पाएँ',
        done: false,
      ));
    } else {
      final next = SyllabusStore.nextTopic(sylExam, doneMap);
      if (next == null) {
        tasks.add(const PlanTask(
          id: 'syllabus',
          emoji: '📚',
          title: 'Syllabus complete',
          titleHi: 'सिलेबस पूरा',
          sub: 'Great work! Now revise and take mock tests',
          subHi: 'शानदार! अब रिवीज़न और मॉक टेस्ट दें',
          done: true,
        ));
      } else {
        final did = sylToday >= 1;
        tasks.add(PlanTask(
          id: 'syllabus',
          emoji: '📚',
          title: 'Finish 1 syllabus topic',
          titleHi: 'सिलेबस का 1 टॉपिक पूरा करें',
          sub: did ? 'Topics done today: $sylToday ✓' : 'Next: ${next.topic.en} (${next.subject.en})',
          subHi: did ? 'आज पूरे किए टॉपिक: $sylToday ✓' : 'अगला: ${next.topic.hi} (${next.subject.hi})',
          done: did,
        ));
      }
    }

    tasks.add(PlanTask(
      id: 'speed',
      emoji: '⚡',
      title: 'Speed Maths: 1 round',
      titleHi: 'स्पीड मैथ्स: 1 राउंड',
      sub: speedToday >= 1 ? 'Rounds today: $speedToday ✓' : 'Just 1 minute of calculation practice',
      subHi: speedToday >= 1 ? 'आज के राउंड: $speedToday ✓' : 'सिर्फ़ 1 मिनट की गणना प्रैक्टिस',
      done: speedToday >= 1,
    ));

    return PlanSummary(tasks, daysLeft, exam.name, focusMin);
  }
}
