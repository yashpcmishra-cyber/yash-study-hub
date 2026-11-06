import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../app_globals.dart';
import 'study_time_store.dart';

// =============================================================================
//  StudyTimerService - Study Timer ka dimaag. Ek hi jagah (poori app me ek).
//
//  Timer Study Timer screen ke andar band nahi hota: student timer chalakar
//  Mocks / PDFs / Quiz / kuch bhi khol sakta hai, timer chalta rehta hai aur
//  har screen par chhota floating pill (StudyTimerMiniBar) dikhta hai jisse
//  pause / stop ho sakta hai.
//
//  * Time ghadi (DateTime) se ginta hai - screen band ho ya app background me
//    ho, hisaab sahi rehta hai.
//  * Chalta hua timer phone me save hota hai ('timer_run_state'). Agar Android
//    app ko background me band kar de, to dobara kholne par timer wahin se
//    (ya poora ho chuka ho to poora gina hua) mil jaata hai.
//  * Focus ka har poora minute StudyTimeStore me jaata hai (wahan se 1 XP /
//    minute milta hai). Break ka time count nahi hota.
//  * Firestore ko 0 reads / 0 writes.
// =============================================================================

class StudyTimerService extends ChangeNotifier with WidgetsBindingObserver {
  StudyTimerService._();
  static final StudyTimerService instance = StudyTimerService._();

  static const _kRun = 'timer_run_state'; // 'ysh' prefix nahi, taaki backup me na jaye
  static const _kSubject = 'ysh5_focus_subject';
  static const _kSubjSecs = 'ysh5_focus_subj_secs';
  static const _kMinutes = 'ysh5_focus_minutes';
  static const _kBreak = 'ysh5_focus_break';
  static const _kGoal = 'ysh5_focus_goal_min';

  /// [emoji, English, Hindi]. English naam hi subject ki key hai.
  static const List<List<String>> subjects = [
    ['📐', 'Maths', 'गणित'],
    ['🧩', 'Reasoning', 'रीजनिंग'],
    ['📖', 'English', 'अंग्रेज़ी'],
    ['🌍', 'GK / GS', 'सामान्य ज्ञान'],
    ['📰', 'Current Affairs', 'करेंट अफेयर्स'],
    ['✍️', 'Other', 'अन्य'],
  ];

  bool isBreak = false;
  bool running = false;
  int focusMin = 25;
  int breakMin = 5;
  int goalMin = 120;
  int totalSec = 25 * 60;
  int remainSec = 25 * 60;
  String subject = 'Maths';
  int sessionsThisRun = 0; // app khulne ke baad poore hue focus sessions

  /// Study Timer screen khuli hai? (Tab floating pill chhup jaata hai.)
  bool screenOpen = false;

  /// Study Timer screen kholne ka kaam (StudyTimerMiniBar set karta hai) -
  /// isse service ko screen file import nahi karni padti.
  VoidCallback? openHandler;

  int _credited = 0; // is session ke kitne second StudyTimeStore me jud chuke
  DateTime? _endAt;
  Timer? _ticker;
  bool _inited = false;
  bool _finishing = false;
  Future<void> _creditChain = Future<void>.value();

  bool get started => remainSec < totalSec;

  /// Floating pill dikhana hai? (chal raha ho ya beech me ruka ho)
  bool get active => running || started;

  void _notify() => notifyListeners();

  void setScreenOpen(bool v) {
    if (screenOpen == v) return;
    screenOpen = v;
    _notify();
  }

  // ------------------------------------------------------------------ setup

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_kSubject);
      if (s != null && subjects.any((e) => e[1] == s)) subject = s;
      final m = p.getInt(_kMinutes);
      if (m != null && m >= 1 && m <= 180) focusMin = m;
      final b = p.getInt(_kBreak);
      if (b != null && b >= 1 && b <= 60) breakMin = b;
      final g = p.getInt(_kGoal);
      if (g != null && g >= 10 && g <= 1440) goalMin = g;
      totalSec = focusMin * 60;
      remainSec = totalSec;
      await _restoreRun(p);
    } catch (_) {}
    _notify();
  }

  Future<void> _restoreRun(SharedPreferences p) async {
    final raw = p.getString(_kRun);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return;
      final end = DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt());
      final total = (m['total'] as num).toInt();
      if (total < 60 || total > 180 * 60) {
        await p.remove(_kRun);
        return;
      }
      isBreak = m['brk'] == true;
      totalSec = total;
      _credited = (m['cred'] as num?)?.toInt() ?? 0;
      final sub = m['subj'];
      if (sub is String && subjects.any((e) => e[1] == sub)) subject = sub;
      final ms = end.difference(DateTime.now()).inMilliseconds;
      if (ms > 0) {
        remainSec = (ms / 1000).ceil();
        _endAt = end;
        running = true;
        _startTicker();
      } else {
        remainSec = 0;
        await _finish(silent: true);
      }
    } catch (_) {
      await p.remove(_kRun);
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      final end = _endAt;
      if (running && end != null) {
        await p.setString(
          _kRun,
          jsonEncode({
            'end': end.millisecondsSinceEpoch,
            'total': totalSec,
            'brk': isBreak,
            'subj': subject,
            'cred': _credited,
          }),
        );
      } else {
        await p.remove(_kRun);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (running) _tick();
    } else if (state == AppLifecycleState.paused) {
      if (running) {
        remainSec = _calcRemain();
        _credit(force: true); // app background me gayi: ab tak ka time turant save
        _persist();
      }
    }
  }

  // ------------------------------------------------------------------ timer

  int _calcRemain() {
    final end = _endAt;
    if (end == null) return remainSec;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void start() {
    if (running || _finishing) return;
    HapticFeedback.mediumImpact();
    running = true;
    _endAt = DateTime.now().add(Duration(seconds: remainSec));
    _startTicker();
    _persist();
    _notify();
  }

  void _tick() {
    if (!running) return;
    remainSec = _calcRemain();
    if (remainSec <= 0) {
      _finish();
    } else {
      _credit(); // har poore minute par
      _notify();
    }
  }

  void pause() {
    if (!running) return;
    _ticker?.cancel();
    remainSec = _calcRemain();
    running = false;
    _endAt = null;
    _persist();
    if (remainSec <= 0) {
      _notify();
      _finish();
      return;
    }
    _credit(force: true);
    _notify();
  }

  /// Stop / Reset: jitna time ho chuka wo save rehta hai, timer shuru par laut aata hai.
  void reset() {
    _ticker?.cancel();
    if (running) remainSec = _calcRemain();
    _credit(force: true);
    running = false;
    _endAt = null;
    remainSec = totalSec;
    _credited = 0;
    _persist();
    _notify();
  }

  Future<void> _credit({bool force = false}) async {
    if (isBreak) return;
    final elapsed = totalSec - remainSec;
    final pending = elapsed - _credited;
    if (pending <= 0) return;
    if (!force && pending < 60) return;
    _credited = elapsed;
    final subj = subject;
    // Ek ke baad ek likhte hain, taaki do likhawat aapas me na takrayein.
    _creditChain = _creditChain.then((_) async {
      await _addSubject(subj, pending);
      await StudyTimeStore.addSeconds(pending);
    });
    await _creditChain;
  }

  Future<void> _finish({bool silent = false}) async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final wasBreak = isBreak;
    final doneMin = totalSec ~/ 60;
    final subj = subject;
    running = false;
    _endAt = null;
    remainSec = 0;
    _notify();
    if (!silent) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 350), () => HapticFeedback.heavyImpact());
    }
    if (!wasBreak) {
      await _credit(force: true);
      await StudyTimeStore.addSession();
      sessionsThisRun++;
    }
    _prepareInternal(!wasBreak);
    _finishing = false;
    await _persist();
    _notify();

    final String title;
    final String body;
    final String yes;
    if (wasBreak) {
      title = 'Break over! / ब्रेक खत्म!';
      body = 'Ready for the next focus session?\nअगले फोकस सेशन के लिए तैयार?';
      yes = 'Start focus / फोकस शुरू';
    } else {
      title = '🎉 Session complete! / सेशन पूरा!';
      body = 'You focused $doneMin min on $subj (≈ +$doneMin XP).\n'
          'आपने $subj पर $doneMin मिनट फोकस किया।\n\n'
          'Take a $breakMin-min break?\n$breakMin मिनट का ब्रेक लें?';
      yes = 'Start break / ब्रेक शुरू';
    }

    if (silent) {
      _snack(wasBreak ? '☕ Your break is over. / आपका ब्रेक खत्म हो गया।' : '🎉 Focus session done: $doneMin min on $subj. / $doneMin मिनट का सेशन पूरा।');
      return;
    }
    final ctx = appNavigatorKey.currentContext;
    if (screenOpen && ctx != null) {
      final go = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (dctx) => AlertDialog(
          backgroundColor: AppC.card2,
          title: Text(title, style: TextStyle(color: AppC.text, fontSize: 17)),
          content: Text(body, style: TextStyle(color: AppC.text70, fontSize: 13.5, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Later / बाद में')),
            TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(yes)),
          ],
        ),
      );
      if (go == true) start();
    } else {
      // Student Mock / PDF / Quiz me hai: beech me dialog nahi, sirf chhota message.
      _snack(wasBreak ? '☕ Break over! Tap to start the next focus. / ब्रेक खत्म!' : '🎉 Focus session done ($doneMin min)! Take a break. / सेशन पूरा! ब्रेक लें।', openTimer: true);
    }
  }

  void _snack(String msg, {bool openTimer = false}) {
    try {
      final messenger = appMessengerKey.currentState;
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 8),
        action: openTimer ? SnackBarAction(label: 'Open', onPressed: openScreen) : null,
      ));
    } catch (_) {}
  }

  /// Study Timer screen kholta hai (floating pill / message se).
  void openScreen() {
    if (screenOpen) return;
    openHandler?.call();
  }

  void _prepareInternal(bool toBreak) {
    isBreak = toBreak;
    totalSec = (toBreak ? breakMin : focusMin) * 60;
    remainSec = totalSec;
    _credited = 0;
    running = false;
    _endAt = null;
  }

  /// Focus <-> Break (timer ruka hua hona chahiye).
  void prepare(bool toBreak) {
    if (running) return;
    _prepareInternal(toBreak);
    _persist();
    _notify();
  }

  void setMinutes(int m) {
    if (running) return;
    if (isBreak) {
      breakMin = m;
    } else {
      focusMin = m;
    }
    totalSec = m * 60;
    remainSec = totalSec;
    _credited = 0;
    _saveSettings(minutes: isBreak ? null : m, breakMin: isBreak ? m : null);
    _notify();
  }

  void setSubject(String s) {
    // Chalte session me bhi badal sakte hain: ab tak ka time purane subject ko jaata hai.
    if (running) _credit(force: true);
    subject = s;
    _saveSettings(subject: s);
    if (running) _persist();
    _notify();
  }

  void setGoal(int minutes) {
    goalMin = minutes;
    _saveSettings(goalMin: minutes);
    _notify();
  }

  // ------------------------------------------------------------ preferences

  Future<void> _saveSettings({String? subject, int? minutes, int? breakMin, int? goalMin}) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (subject != null) await p.setString(_kSubject, subject);
      if (minutes != null) await p.setInt(_kMinutes, minutes);
      if (breakMin != null) await p.setInt(_kBreak, breakMin);
      if (goalMin != null) await p.setInt(_kGoal, goalMin);
    } catch (_) {}
  }

  Future<Map<String, int>> subjectSecs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kSubjSecs);
      if (raw == null || raw.isEmpty) return <String, int>{};
      final m = jsonDecode(raw);
      if (m is Map) {
        final out = <String, int>{};
        for (final e in m.entries) {
          final v = e.value;
          if (v is num) out[e.key.toString()] = v.toInt();
        }
        return out;
      }
    } catch (_) {}
    return <String, int>{};
  }

  Future<void> _addSubject(String subj, int sec) async {
    if (sec <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      final m = await subjectSecs();
      m[subj] = (m[subj] ?? 0) + sec;
      await p.setString(_kSubjSecs, jsonEncode(m));
    } catch (_) {}
  }
}
