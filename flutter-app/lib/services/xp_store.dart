import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_globals.dart';

// =============================================================================
//  XpStore - XP (experience points) aur Level. Sab kuch sirf student ke phone me
//  (SharedPreferences). Firestore ko 0 reads / 0 writes.
//
//  XP kahan se milta hai (StudyStore / StudyTimeStore / RevisionStore waghera
//  apne aap yahan add() bulate hain, screens ko kuch karna nahi padta):
//    - har sawal jo hal kiya ............ 2 XP
//    - mock test poora karna ............ 20 XP (+10 agar 80% ya zyada)
//    - Daily Quiz (pehli baar) .......... 15 XP
//    - Study Timer ...................... 1 XP har poore minute par
//    - notebook ki galti sudharna ....... 5 XP
//    - flashcard "yaad ho gaya" ......... 2 XP
//    - Speed Maths round ................ 5 XP
//    - syllabus topic poora ............. 3 XP
//    - daily goal poora ................. 25 XP
//    - streak badhna .................... 10 XP + (streak ke din, max 30)
//
//  Level: Level 2 = 100 XP, Level 3 = 300, Level 4 = 600, Level 5 = 1000 ...
//  (Level L shuru hota hai 50 * (L-1) * L XP par.)
//
//  Jab XP milta hai to chhota sa "+XP" snackbar dikhta hai (1.2 second ke andar
//  ke saare XP ek saath jod kar), aur level badhne par "Level N" ka message.
// =============================================================================

class XpInfo {
  final int total;
  final int level;
  final int intoLevel; // is level me kitna XP kama liya
  final int forLevel; // is level ko poora karne ke liye kitna chahiye
  final int today;
  const XpInfo({
    required this.total,
    required this.level,
    required this.intoLevel,
    required this.forLevel,
    required this.today,
  });

  double get ratio => forLevel <= 0 ? 0.0 : (intoLevel / forLevel).clamp(0.0, 1.0).toDouble();
  int get toNext => (forLevel - intoLevel) < 0 ? 0 : (forLevel - intoLevel);
  String get title => XpStore.levelTitle(level);
}

class XpStore {
  XpStore._();

  static const _kTotal = 'ysh4_xp_total';
  static const _kDay = 'ysh4_xp_day';
  static const _kDayXp = 'ysh4_xp_day_xp';
  static const _kFocusRemSec = 'ysh4_xp_focus_rem_sec'; // timer ke bache hue second (60 se kam)

  /// XP badalne par ye number badhta hai - Home ka XP card isse refresh hota hai.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  // ------------------------------------------------------------ level math

  /// Level [l] shuru hone ke liye total XP. Level 1 = 0, Level 2 = 100, Level 3 = 300 ...
  static int xpAtLevel(int l) => l <= 1 ? 0 : 50 * (l - 1) * l;

  static int levelForXp(int xp) {
    var l = 1;
    while (xpAtLevel(l + 1) <= xp) {
      l++;
      if (l > 200) break; // suraksha: infinite loop nahi
    }
    return l;
  }

  static String levelTitle(int level) {
    if (level >= 20) return 'Legend / लीजेंड';
    if (level >= 12) return 'Champion / चैंपियन';
    if (level >= 7) return 'Achiever / विजेता';
    if (level >= 3) return 'Learner / जिज्ञासु';
    return 'Beginner / शुरुआती';
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --------------------------------------------------------------- reading

  static Future<XpInfo> info() async {
    final p = await SharedPreferences.getInstance();
    final total = p.getInt(_kTotal) ?? 0;
    final level = levelForXp(total);
    final start = xpAtLevel(level);
    final next = xpAtLevel(level + 1);
    final today = p.getString(_kDay) == _dayKey(DateTime.now()) ? (p.getInt(_kDayXp) ?? 0) : 0;
    return XpInfo(total: total, level: level, intoLevel: total - start, forLevel: next - start, today: today);
  }

  static Future<int> total() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kTotal) ?? 0;
  }

  // --------------------------------------------------------------- writing

  static int _pending = 0;
  static int _pendingLevel = 0; // 0 = level nahi badha
  static Timer? _timer;

  /// [amount] XP jodta hai. Kabhi exception nahi fenkta (study ka kaam rukna nahi chahiye).
  static Future<void> add(int amount) async {
    if (amount <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      final before = p.getInt(_kTotal) ?? 0;
      final after = before + amount;
      await p.setInt(_kTotal, after);
      final t = _dayKey(DateTime.now());
      final cur = p.getString(_kDay) == t ? (p.getInt(_kDayXp) ?? 0) : 0;
      await p.setString(_kDay, t);
      await p.setInt(_kDayXp, cur + amount);
      _bump();

      final lvBefore = levelForXp(before);
      final lvAfter = levelForXp(after);
      _pending += amount;
      if (lvAfter > lvBefore) _pendingLevel = lvAfter;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 1200), _flushToast);
    } catch (_) {
      // XP na bhi jude to koi baat nahi.
    }
  }

  /// Study Timer ke second jodta hai: har poore 60 second par 1 XP.
  static Future<void> addFocusSeconds(int seconds) async {
    if (seconds <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      final sum = (p.getInt(_kFocusRemSec) ?? 0) + seconds;
      final mins = sum ~/ 60;
      await p.setInt(_kFocusRemSec, sum % 60);
      if (mins > 0) await add(mins);
    } catch (_) {}
  }

  static void _flushToast() {
    final xp = _pending;
    final lv = _pendingLevel;
    _pending = 0;
    _pendingLevel = 0;
    if (xp <= 0) return;
    try {
      final messenger = appMessengerKey.currentState;
      if (messenger == null) return;
      final text = lv > 0 ? '⭐ +$xp XP  •  🎉 Level $lv! / लेवल $lv!' : '⭐ +$xp XP';
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        duration: Duration(seconds: lv > 0 ? 3 : 2),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {}
  }
}
