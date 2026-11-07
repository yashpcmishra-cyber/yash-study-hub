import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  ScoreJournalStore - student kisi bhi test series (Testbook, Adda247, coaching
//  ...) ka score yahan haath se likhta hai, taaki progress ek jagah dikhe.
//  Sirf phone me (SharedPreferences, key 'ysh5_score_journal').
//  Firestore ko 0 reads / 0 writes. Cloud Backup me apne aap shamil.
// =============================================================================

class ScoreEntry {
  final String id;
  final String name;
  final double score; // negative marking me kam ya minus bhi ho sakta hai
  final double total; // 0 se bada
  final int ms; // test ki tareekh (millisecondsSinceEpoch)
  final String note;

  const ScoreEntry({
    required this.id,
    required this.name,
    required this.score,
    required this.total,
    required this.ms,
    this.note = '',
  });

  double get percent => total <= 0 ? 0.0 : score * 100 / total;
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(ms);

  Map<String, dynamic> toMap() => {'id': id, 'n': name, 's': score, 't': total, 'd': ms, 'x': note};

  static ScoreEntry? fromMap(dynamic m) {
    try {
      if (m is! Map) return null;
      final id = (m['id'] ?? '').toString();
      final name = (m['n'] ?? '').toString().trim();
      final s = m['s'];
      final t = m['t'];
      final d = m['d'];
      if (id.isEmpty || name.isEmpty || s is! num || t is! num || d is! num) return null;
      if (t <= 0) return null;
      return ScoreEntry(
        id: id,
        name: name,
        score: s.toDouble(),
        total: t.toDouble(),
        ms: d.toInt(),
        note: (m['x'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class ScoreJournalStore {
  ScoreJournalStore._();

  static const _kList = 'ysh5_score_journal';
  static const int maxEntries = 200;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Nayi tareekh pehle (sabse nayi test sabse upar).
  static Future<List<ScoreEntry>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kList);
      if (raw == null || raw.isEmpty) return <ScoreEntry>[];
      final v = jsonDecode(raw);
      if (v is! List) return <ScoreEntry>[];
      final out = <ScoreEntry>[];
      for (final m in v) {
        final e = ScoreEntry.fromMap(m);
        if (e != null) out.add(e);
      }
      out.sort((a, b) => b.ms.compareTo(a.ms));
      return out;
    } catch (_) {
      return <ScoreEntry>[];
    }
  }

  static Future<void> _write(List<ScoreEntry> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kList, jsonEncode(list.map((e) => e.toMap()).toList()));
    _bump();
  }

  /// Jodta hai. 200 se zyada ho jaye to sabse purani hat jaati hai.
  static Future<bool> add(ScoreEntry e) async {
    try {
      final list = await all();
      list.removeWhere((x) => x.id == e.id);
      list.insert(0, e);
      list.sort((a, b) => b.ms.compareTo(a.ms));
      if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
      await _write(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> remove(String id) async {
    try {
      final list = await all();
      list.removeWhere((x) => x.id == id);
      await _write(list);
    } catch (_) {}
  }

  /// Home card ke liye: [kitne test, average %].
  static Future<List<int>> quickStats() async {
    final list = await all();
    if (list.isEmpty) return <int>[0, 0];
    var sum = 0.0;
    for (final e in list) {
      sum += e.percent;
    }
    return <int>[list.length, (sum / list.length).round()];
  }
}
