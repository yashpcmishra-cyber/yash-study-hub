import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'study_store.dart';

// =============================================================================
//  BookmarkStore - "Saved Questions" (⭐). Student kisi bhi quiz / free MCQ
//  sawal par star dabakar use hamesha ke liye save kar sakta hai.
//
//  * Galtiyon (Mistake Notebook) ki tarah 30 din baad nahi hatte - jab tak
//    student khud na hataye.
//  * Sirf phone me (SharedPreferences, key 'ysh5_bookmarks'). Firestore ko
//    0 reads / 0 writes. Cloud Backup ye key apne aap save kar leta hai.
//  * Max 300 sawal (backup chhota rehta hai).
// =============================================================================

enum BookmarkResult { saved, removed, full }

class BookmarkItem {
  final String key;
  final MockQuestion question;
  final int savedMs; // millisecondsSinceEpoch
  final String source; // kis quiz / set se save kiya

  const BookmarkItem({
    required this.key,
    required this.question,
    required this.savedMs,
    this.source = '',
  });

  Map<String, dynamic> toMap() => {
        'k': key,
        'q': question.toMap(),
        't': savedMs,
        'src': source,
      };

  static BookmarkItem? fromMap(dynamic m) {
    try {
      if (m is! Map) return null;
      final q = MockQuestion.fromMap(Map<String, dynamic>.from(m['q'] as Map));
      if (q.text.trim().isEmpty || q.options.length < 2) return null;
      return BookmarkItem(
        key: (m['k'] ?? StudyStore.qKey(q)).toString(),
        question: q,
        savedMs: (m['t'] as num?)?.toInt() ?? 0,
        source: (m['src'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class BookmarkStore {
  BookmarkStore._();

  static const int maxItems = 300;
  static const _kItems = 'ysh5_bookmarks';

  /// Sawal save / hatne par badalta hai.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  static String keyOf(MockQuestion q) => StudyStore.qKey(q);

  /// Sabse naya upar.
  static Future<List<BookmarkItem>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kItems);
      if (raw == null || raw.isEmpty) return <BookmarkItem>[];
      final data = jsonDecode(raw);
      if (data is! List) return <BookmarkItem>[];
      final list = <BookmarkItem>[];
      for (final e in data) {
        final b = BookmarkItem.fromMap(e);
        if (b != null) list.add(b);
      }
      list.sort((a, b) => b.savedMs.compareTo(a.savedMs));
      return list;
    } catch (_) {
      return <BookmarkItem>[];
    }
  }

  static Future<int> count() async => (await all()).length;

  static Future<Set<String>> keys() async => (await all()).map((e) => e.key).toSet();

  static Future<void> _write(List<BookmarkItem> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kItems, jsonEncode(list.map((e) => e.toMap()).toList()));
    _bump();
  }

  /// Save hai to hata deta hai, nahi hai to save karta hai.
  static Future<BookmarkResult> toggle(MockQuestion q, {String source = ''}) async {
    final k = keyOf(q);
    final list = await all();
    final i = list.indexWhere((e) => e.key == k);
    if (i >= 0) {
      list.removeAt(i);
      await _write(list);
      return BookmarkResult.removed;
    }
    if (list.length >= maxItems) return BookmarkResult.full;
    list.insert(0, BookmarkItem(key: k, question: q, savedMs: DateTime.now().millisecondsSinceEpoch, source: source));
    await _write(list);
    return BookmarkResult.saved;
  }

  static Future<void> remove(String key) async {
    final list = await all();
    list.removeWhere((e) => e.key == key);
    await _write(list);
  }

  static Future<void> clearAll() async {
    await _write(<BookmarkItem>[]);
  }
}
