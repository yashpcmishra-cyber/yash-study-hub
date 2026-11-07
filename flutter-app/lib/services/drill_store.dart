import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_store.dart';
import 'xp_store.dart';

// =============================================================================
//  DrillStore - Reasoning Drill aur GK Flash Quiz ka hisaab (har type ka best
//  score, kitne drill kiye, aaj kitne kiye). Sirf phone me (SharedPreferences,
//  keys 'ysh5_drill_*'). Firestore ko 0 reads / 0 writes. Cloud Backup me apne
//  aap shamil (BackupService 'ysh5_' wali keys le leta hai).
// =============================================================================

/// Ek drill type ka sabse accha result.
class DrillBest {
  final int correct;
  final int total;
  const DrillBest(this.correct, this.total);
  int get percent => total <= 0 ? 0 : (correct * 100 / total).round();
}

class DrillStore {
  DrillStore._();

  static const _kBest = 'ysh5_drill_best'; // {"type": [correct, total]}
  static const _kSessions = 'ysh5_drill_sessions';
  static const _kDay = 'ysh5_drill_day';
  static const _kDayCount = 'ysh5_drill_day_count';

  /// Drill khatam hone par badalta hai (Home card isse refresh hota hai).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

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

  static Future<Map<String, DrillBest>> allBest() async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kBest));
    final out = <String, DrillBest>{};
    m.forEach((k, v) {
      if (v is List) out[k] = DrillBest(_at(v, 0), _at(v, 1));
    });
    return out;
  }

  static Future<int> sessions() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kSessions) ?? 0;
  }

  static Future<int> sessionsToday() async {
    final p = await SharedPreferences.getInstance();
    if (p.getString(_kDay) != StudyStore.today()) return 0;
    return p.getInt(_kDayCount) ?? 0;
  }

  /// Ek drill ka natija save karta hai. Naya best bana to true.
  /// Har drill par 5 XP (kam se kam 1 sawal kiya ho tab).
  static Future<bool> record({
    required String type,
    required int correct,
    required int answered,
    required int total,
  }) async {
    if (answered <= 0 || total <= 0) return false;
    var isBest = false;
    try {
      final p = await SharedPreferences.getInstance();
      final best = _decode(p.getString(_kBest));
      final old = best[type];
      final oldC = _at(old, 0);
      final oldT = _at(old, 1);
      final better = old == null || oldT <= 0 || (correct * oldT) > (oldC * total);
      if (correct > 0 && better) {
        best[type] = <int>[correct, total];
        isBest = true;
        await p.setString(_kBest, jsonEncode(best));
      }
      await p.setInt(_kSessions, (p.getInt(_kSessions) ?? 0) + 1);
      final t = StudyStore.today();
      final cur = p.getString(_kDay) == t ? (p.getInt(_kDayCount) ?? 0) : 0;
      await p.setString(_kDay, t);
      await p.setInt(_kDayCount, cur + 1);
      await XpStore.add(5);
      _bump();
    } catch (_) {
      // hisaab na bhi bane to padhai nahi rukni chahiye
    }
    return isBest;
  }
}
