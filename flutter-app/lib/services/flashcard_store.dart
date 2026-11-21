import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'xp_store.dart';

// =============================================================================
//  FlashcardStore - kaun-kaun se Flashcard "yaad ho gaya" mark hue (card ids).
//  Sirf phone me (SharedPreferences, key 'ysh5_flash_known'). Firestore ko
//  0 reads / 0 writes.
// =============================================================================
class FlashcardStore {
  FlashcardStore._();

  static const _kKnown = 'ysh5_flash_known';

  /// Card yaad mark / reset hone par badalta hai (Home tile isse refresh hota hai).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  /// Yaad ho chuke card ids.
  static Future<Set<String>> known() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kKnown);
      if (raw == null || raw.isEmpty) return <String>{};
      final list = jsonDecode(raw);
      if (list is List) return list.map((e) => e.toString()).toSet();
    } catch (_) {
      // kharab data ho to khali maan lo
    }
    return <String>{};
  }

  /// Card "yaad ho gaya" mark karta hai (pehli baar par 2 XP).
  static Future<void> markKnown(String id) async {
    try {
      final set = await known();
      if (!set.add(id)) return;
      final p = await SharedPreferences.getInstance();
      await p.setString(_kKnown, jsonEncode(set.toList()));
      await XpStore.add(2);
      _bump();
    } catch (_) {
      // save na ho to bhi study chalti rahe
    }
  }

  /// Saari progress saaf.
  static Future<void> reset() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kKnown);
      _bump();
    } catch (_) {
      // koi baat nahi
    }
  }
}
