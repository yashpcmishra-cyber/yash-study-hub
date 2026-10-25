import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_store.dart';

// =============================================================================
//  StudyTimeStore - Study Timer ka hisaab (din-wise padhai ka time).
//  Sirf phone me (SharedPreferences). Firestore ko 0 reads / 0 writes.
//  Din-wise data 35 din tak rakha jaata hai, uske baad apne aap hat jaata hai.
// =============================================================================
class StudyTimeStore {
  StudyTimeStore._();

  static const int keepDays = 35;
  static const _kDays = 'ysh3_study_secs'; // {yyyy-MM-dd: seconds}
  static const _kTotal = 'ysh3_study_total'; // lifetime seconds
  static const _kSessions = 'ysh3_study_sessions'; // lifetime completed focus sessions

  /// Time / session judne par badalta hai (chart apne aap refresh hota hai).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final m = jsonDecode(raw);
      if (m is Map) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Aaj ke khate me [seconds] jodta hai.
  static Future<void> addSeconds(int seconds) async {
    if (seconds <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      final m = _decode(p.getString(_kDays));
      final t = StudyStore.today();
      m[t] = ((m[t] as num?)?.toInt() ?? 0) + seconds;
      // purane din hatao
      final now = DateTime.now();
      final oldest = _key(DateTime(now.year, now.month, now.day - keepDays));
      m.removeWhere((k, _) => k.compareTo(oldest) < 0);
      await p.setString(_kDays, jsonEncode(m));
      await p.setInt(_kTotal, (p.getInt(_kTotal) ?? 0) + seconds);
      _bump();
    } catch (_) {}
  }

  /// Ek poora focus session pura hua.
  static Future<void> addSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kSessions, (p.getInt(_kSessions) ?? 0) + 1);
      _bump();
    } catch (_) {}
  }

  static Future<int> secondsOn(String day) async {
    final p = await SharedPreferences.getInstance();
    return (_decode(p.getString(_kDays))[day] as num?)?.toInt() ?? 0;
  }

  static Future<int> totalSeconds() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kTotal) ?? 0;
  }

  static Future<int> totalSessions() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kSessions) ?? 0;
  }

  /// Pichhle 7 din (purana -> aaj).
  static Future<List<DayStudy>> last7() async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kDays));
    final now = DateTime.now();
    final out = <DayStudy>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      out.add(DayStudy(d, (m[_key(d)] as num?)?.toInt() ?? 0));
    }
    return out;
  }

  /// 3725 sec -> "1h 2m", 600 sec -> "10m", 20 sec -> "<1m"
  static String fmt(int seconds) {
    final m = seconds ~/ 60;
    if (seconds > 0 && m == 0) return '<1m';
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

class DayStudy {
  final DateTime day;
  final int seconds;
  const DayStudy(this.day, this.seconds);
}
