import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  ActivityLog - din-wise "kitne sawal kiye" ka hisaab (Weekly Report ke liye).
//  StudyStore.addGoalProgress() har baar yahan bhi likhta hai.
//  Sirf phone me (SharedPreferences). Firestore ko 0 reads / 0 writes.
//  35 din se purana data apne aap hat jaata hai.
// =============================================================================
class ActivityLog {
  ActivityLog._();

  static const int keepDays = 35;
  static const _kQ = 'ysh4_act_q'; // {yyyy-MM-dd: sawal}

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Aaj se [back] din pehle ki date key (back = 0 -> aaj).
  static String dayKey(int back) {
    final n = DateTime.now();
    return keyOf(DateTime(n.year, n.month, n.day - back));
  }

  /// Aaj se pichhle [count] din ki keys: aaj pehle (aaj, kal, ...).
  static List<String> lastDays(int count, {int skip = 0}) {
    return List<String>.generate(count, (i) => dayKey(i + skip));
  }

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final m = jsonDecode(raw);
      if (m is Map) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Aaj ke khate me [n] sawal jodta hai.
  static Future<void> addQuestions(int n) async {
    if (n <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      final m = _decode(p.getString(_kQ));
      final t = dayKey(0);
      m[t] = ((m[t] as num?)?.toInt() ?? 0) + n;
      final oldest = dayKey(keepDays);
      m.removeWhere((k, _) => k.compareTo(oldest) < 0);
      await p.setString(_kQ, jsonEncode(m));
    } catch (_) {}
  }

  /// Diye gaye dinon ke sawal, usi kram me ({day: count}).
  static Future<Map<String, int>> questionsFor(List<String> days) async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kQ));
    return <String, int>{for (final d in days) d: (m[d] as num?)?.toInt() ?? 0};
  }
}
