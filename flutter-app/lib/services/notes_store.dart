import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  NotesStore - student ke apne Quick Notes (sirf phone me, SharedPreferences).
//  Firestore ko 0 reads / 0 writes. Cloud Backup (Backup screen) in notes ko
//  bhi save kar leta hai (key 'ysh5_notes').
// =============================================================================

class NoteItem {
  final String id;
  final String title;
  final String body;
  final bool pinned;
  final int updatedMs; // millisecondsSinceEpoch

  const NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.updatedMs,
  });

  NoteItem copyWith({String? title, String? body, bool? pinned, int? updatedMs}) => NoteItem(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        pinned: pinned ?? this.pinned,
        updatedMs: updatedMs ?? this.updatedMs,
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'body': body, 'pinned': pinned, 'at': updatedMs};

  static NoteItem? fromMap(dynamic m) {
    if (m is! Map) return null;
    final id = m['id'];
    if (id is! String || id.isEmpty) return null;
    return NoteItem(
      id: id,
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      pinned: m['pinned'] == true,
      updatedMs: (m['at'] as num?)?.toInt() ?? 0,
    );
  }
}

class NotesStore {
  NotesStore._();

  static const int maxNotes = 200;
  static const int maxTitle = 80;
  static const int maxBody = 5000;
  static const _kNotes = 'ysh5_notes';

  /// Note judne / badalne / hatne par badalta hai.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  /// Pinned pehle, phir sabse naya upar.
  static Future<List<NoteItem>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kNotes);
      if (raw == null || raw.isEmpty) return <NoteItem>[];
      final data = jsonDecode(raw);
      if (data is! List) return <NoteItem>[];
      final list = <NoteItem>[];
      for (final e in data) {
        final n = NoteItem.fromMap(e);
        if (n != null) list.add(n);
      }
      list.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedMs.compareTo(a.updatedMs);
      });
      return list;
    } catch (_) {
      return <NoteItem>[];
    }
  }

  static Future<int> count() async => (await all()).length;

  static Future<void> _write(List<NoteItem> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kNotes, jsonEncode(list.map((e) => e.toMap()).toList()));
    _bump();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Naya note ya purana badalna. false = limit poori (200 notes).
  static Future<bool> save(NoteItem note) async {
    final cleanTitle = note.title.trim();
    final cleanBody = note.body.trim();
    final fixed = note.copyWith(
      title: cleanTitle.length > maxTitle ? cleanTitle.substring(0, maxTitle) : cleanTitle,
      body: cleanBody.length > maxBody ? cleanBody.substring(0, maxBody) : cleanBody,
      updatedMs: DateTime.now().millisecondsSinceEpoch,
    );
    final list = await all();
    final i = list.indexWhere((e) => e.id == fixed.id);
    if (i >= 0) {
      list[i] = fixed;
    } else {
      if (list.length >= maxNotes) return false;
      list.add(fixed);
    }
    await _write(list);
    return true;
  }

  static Future<void> delete(String id) async {
    final list = await all();
    list.removeWhere((e) => e.id == id);
    await _write(list);
  }

  static Future<void> setPinned(String id, bool pinned) async {
    final list = await all();
    final i = list.indexWhere((e) => e.id == id);
    if (i < 0) return;
    list[i] = list[i].copyWith(pinned: pinned);
    await _write(list);
  }
}
