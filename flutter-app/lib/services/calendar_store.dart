import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  CalendarStore - Study Calendar ka din-wise hisaab: kitne sawal kiye aur
//  kitni der padhai (Study Timer) ki.
//
//  * ActivityLog (sawal) aur StudyTimeStore (timer) har baar yahan bhi likhte
//    hain, aur ye data ~2 saal tak rehta hai (wo dono sirf 35 din rakhte hain).
//  * Purane 35 din ka data in dono se padhkar mila liya jaata hai, isliye
//    calendar pehle din se hi bhara dikhta hai.
//  * Sirf phone me (SharedPreferences, key 'ysh5_cal_days' = {yyyy-MM-dd: [sawal, second]}).
//    Firestore ko 0 reads / 0 writes. Cloud Backup ye key apne aap save karta hai.
// =============================================================================

class DayActivity {
  final int questions;
  final int seconds;
  const DayActivity(this.questions, this.seconds);

  static const DayActivity none = DayActivity(0, 0);

  int get minutes => seconds ~/ 60;
  bool get active => questions > 0 || seconds >= 60;

  /// Sawal + padhai ke minute (1 sawal ~ 1 minute maan kar).
  int get score => questions + minutes;

  /// Heatmap ka rang-star: 0 (kuch nahi) se 4 (bahut zyada).
  int get level {
    if (!active) return 0;
    final s = score;
    if (s < 15) return 1;
    if (s < 40) return 2;
    if (s < 80) return 3;
    return 4;
  }
}

class CalendarStore {
  CalendarStore._();

  static const int keepDays = 800;
  static const _kDays = 'ysh5_cal_days';
  // Purane (35 din wale) stores ki keys - sirf padhne ke liye.
  static const _kLegacyQ = 'ysh4_act_q'; // {day: sawal}
  static const _kLegacySecs = 'ysh3_study_secs'; // {day: second}

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final m = jsonDecode(raw);
      if (m is Map) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static List<int> _pair(dynamic v) {
    if (v is List && v.length >= 2) {
      return [(v[0] as num?)?.toInt() ?? 0, (v[1] as num?)?.toInt() ?? 0];
    }
    return [0, 0];
  }

  static Future<void> _add(int q, int secs) async {
    try {
      final p = await SharedPreferences.getInstance();
      final m = _decode(p.getString(_kDays));
      final t = keyOf(DateTime.now());
      final cur = _pair(m[t]);
      m[t] = [cur[0] + q, cur[1] + secs];
      if (m.length > keepDays) {
        final now = DateTime.now();
        final oldest = keyOf(DateTime(now.year, now.month, now.day - keepDays));
        m.removeWhere((k, _) => k.compareTo(oldest) < 0);
      }
      await p.setString(_kDays, jsonEncode(m));
    } catch (_) {
      // calendar ki gadbad se padhai ka hisaab nahi rukna chahiye
    }
  }

  /// Aaj ke khate me [n] sawal jodta hai (ActivityLog se bulaya jaata hai).
  static Future<void> addQuestions(int n) async {
    if (n <= 0) return;
    await _add(n, 0);
  }

  /// Aaj ke khate me [seconds] padhai jodta hai (StudyTimeStore se bulaya jaata hai).
  static Future<void> addSeconds(int seconds) async {
    if (seconds <= 0) return;
    await _add(0, seconds);
  }

  /// Saare din ({yyyy-MM-dd: DayActivity}). Purane stores ka data bhi mila hua.
  static Future<Map<String, DayActivity>> all() async {
    final out = <String, DayActivity>{};
    try {
      final p = await SharedPreferences.getInstance();
      final own = _decode(p.getString(_kDays));
      final legQ = _decode(p.getString(_kLegacyQ));
      final legS = _decode(p.getString(_kLegacySecs));
      final keys = <String>{...own.keys, ...legQ.keys, ...legS.keys};
      for (final k in keys) {
        final o = _pair(own[k]);
        final q = (legQ[k] as num?)?.toInt() ?? 0;
        final s = (legS[k] as num?)?.toInt() ?? 0;
        final qq = o[0] > q ? o[0] : q;
        final ss = o[1] > s ? o[1] : s;
        if (qq > 0 || ss > 0) out[k] = DayActivity(qq, ss);
      }
    } catch (_) {
      // khali calendar dikhega
    }
    return out;
  }

  /// Is mahine me kitne din padhai ki (Home tile ke liye).
  static Future<int> activeDaysInMonth(DateTime month) async {
    final all = await CalendarStore.all();
    final prefix = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-';
    var n = 0;
    all.forEach((k, v) {
      if (k.startsWith(prefix) && v.active) n++;
    });
    return n;
  }

  /// Ab tak kul kitne din padhai ki (badge ke liye).
  static Future<int> totalActiveDays() async {
    final all = await CalendarStore.all();
    return all.values.where((e) => e.active).length;
  }
}
