import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/flashcard_data.dart';

// =============================================================================
//  FlashcardStore - kaun se flashcards "yaad hain" (sirf phone me).
//  Cards app ke andar hi bundled hain, isliye internet / Firestore ki zaroorat nahi.
// =============================================================================
class FlashcardStore {
  FlashcardStore._();

  static const _kKnown = 'ysh3_cards_known';

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  /// Sirf wahi ids jo abhi bhi app me maujood hain.
  static Future<Set<String>> known() async {
    final p = await SharedPreferences.getInstance();
    final valid = kFlashcards.map((c) => c.id).toSet();
    return (p.getStringList(_kKnown) ?? const <String>[]).where(valid.contains).toSet();
  }

  static Future<int> knownCount() async => (await known()).length;

  static Future<void> setKnown(String id, bool value) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_kKnown) ?? const <String>[]).toSet();
    if (value) {
      s.add(id);
    } else {
      s.remove(id);
    }
    await p.setStringList(_kKnown, s.toList());
    _bump();
  }

  /// [cat] null ho to saare cards dobara "naye" ho jaate hain.
  static Future<void> reset({String? cat}) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_kKnown) ?? const <String>[]).toSet();
    if (cat == null) {
      s.clear();
    } else {
      final ids = kFlashcards.where((c) => c.cat == cat).map((c) => c.id).toSet();
      s.removeAll(ids);
    }
    await p.setStringList(_kKnown, s.toList());
    _bump();
  }
}
