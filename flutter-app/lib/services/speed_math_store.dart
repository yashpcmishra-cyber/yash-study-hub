import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_store.dart';

// =============================================================================
//  SpeedMathStore - Speed Maths Arena ka hisaab (best score, din-wise rounds).
//  Sirf phone me (SharedPreferences). Firestore ko 0 reads / 0 writes.
//  Din-wise data 35 din tak rakha jaata hai, uske baad apne aap hat jaata hai.
// =============================================================================

/// Ek drill + mode ka best result.
class SpeedBest {
  final int correct;
  final int seconds;
  const SpeedBest(this.correct, this.seconds);
}

class SpeedMathStore {
  SpeedMathStore._();

  static const int keepDays = 35;
  static const String modeRapid = 'r60'; // 60 second Rapid Fire
  static const String modeQuestions = 'q20'; // 20 sawal, time ginte hain
  static const int rapidSeconds = 60;
  static const int questionCount = 20;

  static const _kBest = 'ysh4_sm_best'; // {"drill_mode": [correct, seconds]}
  static const _kDays = 'ysh4_sm_days'; // {yyyy-MM-dd: [rounds, correct, answered]}
  static const _kRounds = 'ysh4_sm_rounds'; // lifetime rounds

  /// Round khatam hone par badalta hai (Home card / Planner apne aap refresh hote hain).
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

  static int _at(dynamic list, int i) {
    if (list is List && i < list.length && list[i] is num) return (list[i] as num).toInt();
    return 0;
  }

  static Future<SpeedBest?> bestFor(String drillId, String mode) async {
    final p = await SharedPreferences.getInstance();
    final v = _decode(p.getString(_kBest))['${drillId}_$mode'];
    if (v is! List) return null;
    return SpeedBest(_at(v, 0), _at(v, 1));
  }

  static Future<Map<String, SpeedBest>> allBests() async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kBest));
    final out = <String, SpeedBest>{};
    m.forEach((k, v) {
      if (v is List) out[k] = SpeedBest(_at(v, 0), _at(v, 1));
    });
    return out;
  }

  /// Ek round ka natija save karta hai. Naya best bana to true.
  /// Sawal ka 5va hissa daily goal me jodte hain (taaki Badges asaani se na khulein).
  static Future<bool> recordRound({
    required String drillId,
    required String mode,
    required int correct,
    required int answered,
    required int seconds,
  }) async {
    var isBest = false;
    try {
      final p = await SharedPreferences.getInstance();

      // best score
      final best = _decode(p.getString(_kBest));
      final key = '${drillId}_$mode';
      final old = best[key];
      final oldC = _at(old, 0);
      final oldS = _at(old, 1);
      if (correct > 0 && (old == null || correct > oldC || (correct == oldC && seconds < oldS))) {
        best[key] = [correct, seconds];
        isBest = true;
        await p.setString(_kBest, jsonEncode(best));
      }

      // din-wise rounds
      final days = _decode(p.getString(_kDays));
      final t = StudyStore.today();
      final cur = days[t];
      days[t] = [_at(cur, 0) + 1, _at(cur, 1) + correct, _at(cur, 2) + answered];
      final now = DateTime.now();
      final oldest = _key(DateTime(now.year, now.month, now.day - keepDays));
      days.removeWhere((k, _) => k.compareTo(oldest) < 0);
      await p.setString(_kDays, jsonEncode(days));

      await p.setInt(_kRounds, (p.getInt(_kRounds) ?? 0) + 1);

      final goalQs = answered ~/ 5;
      if (goalQs > 0) await StudyStore.addGoalProgress(goalQs);
      _bump();
      StudyStore.notifyChanged();
    } catch (_) {}
    return isBest;
  }

  static Future<int> totalRounds() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kRounds) ?? 0;
  }

  static Future<int> roundsOn(String day) async {
    final p = await SharedPreferences.getInstance();
    return _at(_decode(p.getString(_kDays))[day], 0);
  }

  /// Diye gaye dinon ka jod: [rounds, correct, answered].
  static Future<List<int>> sumDays(List<String> days) async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kDays));
    var r = 0;
    var c = 0;
    var a = 0;
    for (final d in days) {
      final v = m[d];
      r += _at(v, 0);
      c += _at(v, 1);
      a += _at(v, 2);
    }
    return [r, c, a];
  }
}
