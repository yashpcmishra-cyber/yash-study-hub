import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'xp_store.dart';

// =============================================================================
//  TypingStore - Typing Speed Test ka hisaab (best WPM, pichhle tests).
//  Sirf phone me (SharedPreferences, keys 'ysh5_typing_*'). Firestore ko
//  0 reads / 0 writes. Cloud Backup ye keys apne aap save kar leta hai.
// =============================================================================

class TypingRecord {
  final int ms; // millisecondsSinceEpoch
  final String lang; // 'en' ya 'hi'
  final int minutes;
  final int wpm; // net WPM
  final int accuracy; // 0..100
  const TypingRecord(this.ms, this.lang, this.minutes, this.wpm, this.accuracy);

  List<dynamic> toList() => [ms, lang, minutes, wpm, accuracy];

  static TypingRecord? fromList(dynamic v) {
    if (v is! List || v.length < 5) return null;
    return TypingRecord(
      (v[0] as num?)?.toInt() ?? 0,
      (v[1] ?? 'en').toString(),
      (v[2] as num?)?.toInt() ?? 1,
      (v[3] as num?)?.toInt() ?? 0,
      (v[4] as num?)?.toInt() ?? 0,
    );
  }
}

class TypingSaveResult {
  final bool newBest;
  final int xp;
  const TypingSaveResult(this.newBest, this.xp);
}

class TypingStore {
  TypingStore._();

  static const int maxHistory = 20;
  static const _kBestEn = 'ysh5_typing_best_en';
  static const _kBestHi = 'ysh5_typing_best_hi';
  static const _kHist = 'ysh5_typing_hist';
  static const _kTests = 'ysh5_typing_tests';

  /// Test poora hone par badalta hai (Home card refresh hota hai).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  static String _bestKey(String lang) => lang == 'hi' ? _kBestHi : _kBestEn;

  static Future<int> best(String lang) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt(_bestKey(lang)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Dono bhashaon me se sabse achha WPM (badge ke liye).
  static Future<int> bestOverall() async {
    final en = await best('en');
    final hi = await best('hi');
    return en > hi ? en : hi;
  }

  static Future<int> totalTests() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt(_kTests) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Naya se purana.
  static Future<List<TypingRecord>> history() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kHist);
      if (raw == null || raw.isEmpty) return <TypingRecord>[];
      final data = jsonDecode(raw);
      if (data is! List) return <TypingRecord>[];
      final out = <TypingRecord>[];
      for (final e in data) {
        final r = TypingRecord.fromList(e);
        if (r != null) out.add(r);
      }
      return out;
    } catch (_) {
      return <TypingRecord>[];
    }
  }

  /// Ek test ka natija save karta hai. Kabhi exception nahi fenkta.
  static Future<TypingSaveResult> record({
    required String lang,
    required int minutes,
    required int wpm,
    required int accuracy,
  }) async {
    var newBest = false;
    var xp = 0;
    try {
      final p = await SharedPreferences.getInstance();
      final prevBest = p.getInt(_bestKey(lang)) ?? 0;
      // Best sirf tab jab accuracy theek ho (sirf random keys dabakar best na bane).
      if (wpm > prevBest && accuracy >= 80) {
        newBest = true;
        await p.setInt(_bestKey(lang), wpm);
      }
      final hist = await history();
      hist.insert(0, TypingRecord(DateTime.now().millisecondsSinceEpoch, lang, minutes, wpm, accuracy));
      if (hist.length > maxHistory) hist.removeRange(maxHistory, hist.length);
      await p.setString(_kHist, jsonEncode(hist.map((e) => e.toList()).toList()));
      await p.setInt(_kTests, (p.getInt(_kTests) ?? 0) + 1);
      // XP: poora test dene par 5 XP (+ achhi accuracy / speed ka bonus). 1 test = max 15 XP.
      if (wpm > 0) {
        xp = 5;
        if (accuracy >= 90) xp += 5;
        if (wpm >= 30 && accuracy >= 90) xp += 5;
        await XpStore.add(xp);
      }
      _bump();
    } catch (_) {
      // natija save na bhi ho to student ko score dikhna chahiye
    }
    return TypingSaveResult(newBest, xp);
  }
}
