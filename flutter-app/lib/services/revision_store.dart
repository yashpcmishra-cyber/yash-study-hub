import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_store.dart';

// =============================================================================
//  RevisionStore - "Smart Revision" (spaced repetition).
//
//  Mistake Notebook ka har galat sawal 1 -> 3 -> 7 -> 15 din ke gap par dobara
//  puchha jaata hai. Sahi jawab = agle gap par; galat jawab = phir kal.
//  4 baar sahi = sawal "pakka" ho gaya aur notebook se hat jaata hai.
//
//  Schedule sirf STUDENT KE PHONE me hai (SharedPreferences) - Firestore ko
//  koi read / write nahi lagta.
// =============================================================================

/// Ek sawal ka revision schedule.
class RevisionItem {
  final SavedQuestion saved;
  final int box; // 0..3 = ab tak kitni baar sahi revise kiya
  final String due; // yyyy-MM-dd
  final bool hasEntry; // schedule me pehle se likha hua hai?
  const RevisionItem(this.saved, this.box, this.due, this.hasEntry);
}

class RevisionOverview {
  final int due; // aaj revision ke liye taiyaar
  final int total; // revision list me kul sawal
  final List<int> perBox; // 4 numbers: step 1..4 me kitne sawal
  final String? nextDue; // agla revision kab (agar aaj kuch due nahi)
  final int mastered; // ab tak kitne sawal pakke hue
  const RevisionOverview({
    this.due = 0,
    this.total = 0,
    this.perBox = const [0, 0, 0, 0],
    this.nextDue,
    this.mastered = 0,
  });
}

class RevisionStore {
  RevisionStore._();

  /// Har step ke baad kitne din ruk kar dobara puchna hai.
  static const List<int> intervals = [1, 3, 7, 15];
  static const int sessionSize = 10;

  static const _kSched = 'ysh3_rev_sched';
  static const _kMastered = 'ysh3_rev_mastered';

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _inDays(int n) {
    final x = DateTime.now();
    return _key(DateTime(x.year, x.month, x.day + n));
  }

  static String _afterSaved(DateTime d, int n) => _key(DateTime(d.year, d.month, d.day + n));

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final m = jsonDecode(raw);
      if (m is Map) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Notebook ke saare galat sawal + unka schedule.
  static Future<List<RevisionItem>> _items() async {
    final p = await SharedPreferences.getInstance();
    final sched = _decode(p.getString(_kSched));
    final mistakes = await StudyStore.mistakes();
    final out = <RevisionItem>[];
    for (final e in mistakes) {
      final raw = sched[e.key];
      var box = 0;
      var due = _afterSaved(e.savedAt, 1); // naya galat sawal: agle din se
      var has = false;
      if (raw is List && raw.length >= 3 && raw[2] == e.savedAt.millisecondsSinceEpoch) {
        box = ((raw[0] as num?)?.toInt() ?? 0).clamp(0, 3).toInt();
        due = raw[1].toString();
        has = true;
      }
      out.add(RevisionItem(e, box, due, has));
    }
    return out;
  }

  static int _byDue(RevisionItem a, RevisionItem b) {
    final c = a.due.compareTo(b.due);
    return c != 0 ? c : a.box.compareTo(b.box);
  }

  /// Aaj revision ke liye taiyaar sawal (sabse purane pehle).
  static Future<List<SavedQuestion>> dueItems({int limit = sessionSize}) async {
    final t = StudyStore.today();
    final items = (await _items()).where((e) => e.due.compareTo(t) <= 0).toList()..sort(_byDue);
    return items.take(limit).map((e) => e.saved).toList();
  }

  /// "Extra practice": jo abhi due nahi hain unme se kuch sawal (schedule nahi badalta).
  static Future<List<SavedQuestion>> extraItems({int limit = sessionSize}) async {
    final items = await _items();
    items.shuffle(Random());
    return items.take(limit).map((e) => e.saved).toList();
  }

  static Future<int> dueCount() async {
    final t = StudyStore.today();
    final items = await _items();
    return items.where((e) => e.due.compareTo(t) <= 0).length;
  }

  static Future<int> masteredCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kMastered) ?? 0;
  }

  static Future<RevisionOverview> overview() async {
    final p = await SharedPreferences.getInstance();
    final t = StudyStore.today();
    final items = await _items();
    final perBox = <int>[0, 0, 0, 0];
    var due = 0;
    String? next;
    for (final e in items) {
      perBox[e.box] += 1;
      if (e.due.compareTo(t) <= 0) {
        due++;
      } else if (next == null || e.due.compareTo(next) < 0) {
        next = e.due;
      }
    }
    return RevisionOverview(
      due: due,
      total: items.length,
      perBox: perBox,
      nextDue: next,
      mastered: p.getInt(_kMastered) ?? 0,
    );
  }

  /// Revision session khatam hone par. [scheduled] = false ho (extra practice)
  /// to schedule nahi badalta, sirf goal me sawal gine jaate hain.
  static Future<void> recordSession({
    required List<SavedQuestion> items,
    required List<int?> answers,
    required bool scheduled,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      final current = await _items();
      final byKey = <String, RevisionItem>{for (final e in current) e.saved.key: e};
      final out = <String, List<dynamic>>{};
      for (final e in current) {
        if (e.hasEntry) out[e.saved.key] = [e.box, e.due, e.saved.savedAt.millisecondsSinceEpoch];
      }
      var answered = 0;
      var mastered = 0;
      final toRemove = <String>[];
      for (var i = 0; i < items.length; i++) {
        final given = i < answers.length ? answers[i] : null;
        if (given == null) continue;
        answered++;
        if (!scheduled) continue;
        final it = byKey[items[i].key];
        if (it == null) continue; // is beech notebook se hat gaya
        final ms = it.saved.savedAt.millisecondsSinceEpoch;
        final correct = given == items[i].question.correctIndex;
        if (correct) {
          final next = it.box + 1;
          if (next >= intervals.length) {
            mastered++;
            toRemove.add(it.saved.key);
            out.remove(it.saved.key);
          } else {
            out[it.saved.key] = [next, _inDays(intervals[next]), ms];
          }
        } else {
          out[it.saved.key] = [0, _inDays(intervals[0]), ms];
        }
      }
      await p.setString(_kSched, jsonEncode(out));
      if (mastered > 0) await p.setInt(_kMastered, (p.getInt(_kMastered) ?? 0) + mastered);
      for (final k in toRemove) {
        await StudyStore.removeMistake(k);
      }
      if (answered > 0) await StudyStore.addGoalProgress(answered);
      StudyStore.notifyChanged();
    } catch (_) {
      // Revision ka data kabhi quiz screen ko rokna nahi chahiye.
    }
  }
}
