import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark / Light theme ka controller. Student ka choice phone me save rehta hai
/// (SharedPreferences), isliye app dobara kholne par wahi theme milti hai.
class AppTheme {
  AppTheme._();

  /// true = Light theme, false = Dark theme (default).
  static final ValueNotifier<bool> light = ValueNotifier<bool>(false);

  static bool get isLight => light.value;

  /// Light theme ka MASTER SWITCH. `false` kar do to theme icon Home se hat jaata hai
  /// aur sabhi students ko hamesha purani Dark theme milti hai (sirf isi ek file ko
  /// dobara upload karna hota hai).
  static const bool enabled = true;

  static const String _prefKey = 'theme_is_light';

  /// App start par (runApp se pehle) saved choice padhta hai.
  static Future<void> load() async {
    if (!enabled) {
      light.value = false;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      light.value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      // Padh nahi paya to Dark theme hi rahegi.
    }
  }

  /// Dark <-> Light badalta hai, poori app turant naye colours me redraw
  /// hoti hai aur choice save ho jaati hai.
  static Future<void> toggle() async {
    light.value = !light.value;
    _rebuildEverything();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, light.value);
    } catch (_) {
      // Save fail ho gaya to bhi abhi ki theme badal chuki hai.
    }
  }

  // Har widget ko dobara draw karwata hai (const widgets bhi), taaki sab
  // screens naye colours utha lein. State (scroll, tab, typed text) safe rehta hai.
  static void _rebuildEverything() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}

/// Saare colours ek jagah. Dark wale values bilkul purane jaise hain.
/// Light theme: top/bottom patti navy (#000066), baaki screen white.
class AppC {
  AppC._();

  static bool get _l => AppTheme.light.value;
  static Color _p(Color dark, Color light) => _l ? light : dark;

  // ---- Surfaces ----
  static Color get bg => _p(const Color(0xFF050B24), const Color(0xFFFFFFFF));
  static Color get card => _p(const Color(0xFF081136), const Color(0xFFF4F6FF));
  static Color get card2 => _p(const Color(0xFF101D57), const Color(0xFFE8ECFF));
  static Color get cardA60 => _p(const Color(0x99081136), const Color(0x99F4F6FF));
  static Color get cardA80 => _p(const Color(0xCC081136), const Color(0xCCF4F6FF));
  static Color get tile => _p(const Color(0xFF080E2A), const Color(0xFFFFFFFF));
  static Color get panel => _p(const Color(0xFF0D1A4D), const Color(0xFFEEF1FF));
  static Color get chip => _p(const Color(0xFF192B72), const Color(0xFFE3E8FF));
  static Color get soft => _p(const Color(0xFF1D3184), const Color(0xFFD6DCF7));
  static Color get line => _p(const Color(0xFF16276A), const Color(0xFFC5CEF5));
  static Color get coal => _p(const Color(0xFF0A0A0A), const Color(0xFFC5CEF5));
  static Color get divider => _p(Colors.grey, const Color(0xFFD0D7F5));
  static Color get divider2 => _p(const Color(0xFF2A2D3A), const Color(0xFFD0D7F5));
  static Color get line2 => _p(Colors.grey.shade800, const Color(0xFFC5CEF5));
  static Color get dotOff => _p(Colors.grey.shade700, const Color(0xFFB4BBEA));

  // ---- Top bar / bottom bar ----
  /// Light theme me top bar aur bottom bar ka navy (image wala colour).
  static const Color navy = Color(0xFF000066);
  static Color get appBar => _p(Colors.transparent, navy);
  static Color get navBar => _p(const Color(0xE60A1440), navy);
  static Color get navLine => _p(const Color(0xFF16276A), const Color(0xFF1F1F8A));
  static Color get navInactive => _p(Colors.grey, const Color(0xFFB4BBEA));

  // ---- Text / icons ----
  static Color get text => _p(Colors.white, const Color(0xFF0B1240));
  static Color get text70 => _p(Colors.white70, const Color(0xFF3A4270));
  static Color get text60 => _p(Colors.white60, const Color(0xFF454D78));
  static Color get text54 => _p(Colors.white54, const Color(0xFF565E86));
  static Color get text38 => _p(Colors.white38, const Color(0xFF6B7396));
  static Color get text30 => _p(Colors.white30, const Color(0xFF8A92B5));
  static Color get text24 => _p(Colors.white24, const Color(0xFFB4BCE6));
  static Color get text12 => _p(Colors.white12, const Color(0xFFD6DCF7));
  static Color get muted => _p(Colors.grey, const Color(0xFF5B6385));
  static Color get mutedBlue => _p(const Color(0xFF9AA3C7), const Color(0xFF5B6385));
  static Color get textSoft => _p(const Color(0xFFD7DCF2), const Color(0xFF28305E));
  static Color get textSoft2 => _p(const Color(0xFFDDE3FF), const Color(0xFF28305E));

  // ---- Yellow ----
  /// Yellow text / icon / switch / tab (white par bilkul nahi dikhta, isliye light me blue).
  static Color get accent => _p(const Color(0xFFFFFF29), const Color(0xFF1A3BCC));
  /// Beech ka (medium) status colour: dark me yellow, light me gehra amber.
  static Color get mid => _p(const Color(0xFFFFFF29), const Color(0xFFB45F06));
  /// Yellow fill (button, chip, bubble). Light me thoda gehra yellow taaki white par dikhe.
  static Color get gold => _p(const Color(0xFFFFFF29), const Color(0xFFFFD400));
  static Color get goldWash => _p(const Color(0x22FFFF29), const Color(0x55FFD400));
  static Color get goldWash2 => _p(const Color(0x33FFFF29), const Color(0x77FFD400));
  /// Yellow fill ke upar ka gehra text (dono theme me same).
  static const Color onGold = Color(0xFF081136);

  // ---- Status colours (light me gehre shades taaki white par padhe jaa sakein) ----
  static Color get red => _p(Colors.redAccent, const Color(0xFFC62828));
  static Color get redDeep => _p(Colors.red, const Color(0xFFC62828));
  static Color get green => _p(Colors.greenAccent, const Color(0xFF1B7A3E));
  static Color get greenDeep => _p(Colors.green, const Color(0xFF1B7A3E));
  static Color get orange => _p(Colors.orangeAccent, const Color(0xFFD84315));
  static Color get sky => _p(Colors.lightBlueAccent, const Color(0xFF0277BD));
  static Color get amber => _p(Colors.amber, const Color(0xFFB45F06));
  static Color get redText => _p(const Color(0xFFFF5252), const Color(0xFFC62828));
  static Color get greenWash => _p(const Color(0x2269F0AE), const Color(0x221B7A3E));
  static Color get redWash => _p(const Color(0x22FF5252), const Color(0x1AC62828));
  static Color get orangeWash => _p(const Color(0x33FF9800), const Color(0x22D84315));
  static Color get glass33 => _p(const Color(0x33FFFFFF), const Color(0xFFC5CEF5));
  static Color get glass22 => _p(const Color(0x22FFFFFF), const Color(0xFFD6DCF7));
  static Color get tileBorder => _p(const Color(0x66FFE81F), const Color(0xFFC5CEF5));
  static Color get softYellowText => _p(const Color(0xFFFFFF2E), const Color(0xFF1A3BCC));

  // ---- Brand buttons (white text safe in both themes) ----
  static Color get telegram => _p(const Color(0xFF2AABEE), const Color(0xFF0F7BB8));
  static Color get whatsapp => _p(const Color(0xFF25D366), const Color(0xFF0E7C3F));
  static Color get youtube => _p(const Color(0xFFFF0000), const Color(0xFFD32F2F));
  static Color get instagram => _p(const Color(0xFFD6249F), const Color(0xFFB5177F));
  static Color get facebook => _p(const Color(0xFF1877F2), const Color(0xFF1259B8));
}
