import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  ChecklistStore - "Exam Day Checklist": exam se pehle ki tayyari ki list.
//  Ticks aur student ke apne items sirf phone me (SharedPreferences, key
//  'ysh5_checklist'). Firestore ko 0 reads / 0 writes. Cloud Backup me apne
//  aap shamil (prefix 'ysh5_').
//  Naya default item jodna ho to kisi group ke end me ek line add karo, id
//  unique rakho. Purani ids kabhi mat badlo.
// =============================================================================

class CheckItem {
  final String id;
  final String en;
  final String hi;
  const CheckItem(this.id, this.en, this.hi);
}

class CheckGroup {
  final String emoji;
  final String en;
  final String hi;
  final List<CheckItem> items;
  const CheckGroup(this.emoji, this.en, this.hi, this.items);
}

const List<CheckGroup> kCheckGroups = [
  CheckGroup('📄', 'Documents', 'दस्तावेज़', [
    CheckItem('doc1', 'Admit card / e-call letter printed (carry 2 copies)', 'एडमिट कार्ड / ई-कॉल लेटर का प्रिंट (2 कॉपी साथ रखें)'),
    CheckItem('doc2', 'Original photo ID that your admit card allows (Aadhaar, PAN, Voter ID, Driving Licence, Passport ...)', 'एडमिट कार्ड में मान्य मूल फोटो पहचान-पत्र (आधार, पैन, वोटर ID, ड्राइविंग लाइसेंस, पासपोर्ट ...)'),
    CheckItem('doc3', 'Passport-size photos (as many as the admit card asks)', 'पासपोर्ट साइज़ फोटो (एडमिट कार्ड में जितनी माँगी हों)'),
    CheckItem('doc4', 'Declaration / undertaking form, if the admit card mentions one (filled as instructed)', 'घोषणा-पत्र / अंडरटेकिंग फॉर्म, यदि एडमिट कार्ड में हो (निर्देश अनुसार भरा हुआ)'),
  ]),
  CheckGroup('🗺️', 'Day before the exam', 'परीक्षा से एक दिन पहले', [
    CheckItem('pre1', 'Exam centre address and route checked on a map (visit it if you can)', 'परीक्षा केंद्र का पता और रास्ता मैप पर देख लिया (हो सके तो एक बार जाकर देखें)'),
    CheckItem('pre2', 'Reporting time and gate-closing time noted down', 'रिपोर्टिंग समय और गेट बंद होने का समय नोट कर लिया'),
    CheckItem('pre3', 'All instructions on the admit card read', 'एडमिट कार्ड के सारे निर्देश पढ़ लिए'),
    CheckItem('pre4', 'Travel plan fixed - reach at least 45-60 minutes early', 'यात्रा की योजना तय - कम से कम 45-60 मिनट पहले पहुँचें'),
    CheckItem('pre5', 'Only light revision of short notes and formulas, no new topics', 'सिर्फ़ छोटे नोट्स और सूत्रों का हल्का रिविज़न, कोई नया टॉपिक नहीं'),
    CheckItem('pre6', 'Early sleep (7-8 hours)', 'जल्दी सोना (7-8 घंटे की नींद)'),
  ]),
  CheckGroup('🎒', 'What to carry (if allowed)', 'साथ क्या ले जाएँ (अनुमति हो तो)', [
    CheckItem('car1', 'Black / blue ball pens (2-3), as your exam asks', 'काले / नीले बॉल पेन (2-3), परीक्षा के नियम अनुसार'),
    CheckItem('car2', 'Pencil, eraser, sharpener (only if allowed)', 'पेंसिल, रबर, शार्पनर (सिर्फ़ अनुमति हो तो)'),
    CheckItem('car3', 'Transparent water bottle (only if allowed)', 'पारदर्शी पानी की बोतल (सिर्फ़ अनुमति हो तो)'),
    CheckItem('car4', 'Some cash for travel', 'यात्रा के लिए कुछ नक़द'),
    CheckItem('car5', 'Mobile, smartwatch, earphones, calculator and bag left at home (usually not allowed)', 'मोबाइल, स्मार्टवॉच, ईयरफ़ोन, कैलकुलेटर और बैग घर पर (आमतौर पर अनुमति नहीं)'),
  ]),
  CheckGroup('🏫', 'At the exam centre', 'परीक्षा केंद्र पर', [
    CheckItem('cen1', 'Roll number and seat checked', 'रोल नंबर और सीट जाँच ली'),
    CheckItem('cen2', 'Instructions on the paper / screen read before starting', 'शुरू करने से पहले प्रश्न-पत्र / स्क्रीन के निर्देश पढ़े'),
    CheckItem('cen3', 'OMR / personal details (roll no., set code) filled carefully', 'OMR / व्यक्तिगत विवरण (रोल नंबर, सेट कोड) ध्यान से भरा'),
    CheckItem('cen4', 'Plan: easy questions first, keep 5-10 minutes for review', 'योजना: पहले आसान प्रश्न, 5-10 मिनट रिव्यू के लिए बचाएँ'),
  ]),
];

/// Student ka apna joda hua item.
class CustomCheck {
  final String id;
  final String text;
  final bool done;
  const CustomCheck(this.id, this.text, this.done);
}

class ChecklistData {
  final Set<String> done; // default items ki ids jo tick hain
  final List<CustomCheck> custom;
  const ChecklistData(this.done, this.custom);
}

class ChecklistStore {
  ChecklistStore._();

  static const _kKey = 'ysh5_checklist';
  static const int maxCustom = 30;
  static const int maxText = 80;

  /// Tick / item badalne par badalta hai.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  static int get defaultTotal {
    var n = 0;
    for (final g in kCheckGroups) {
      n += g.items.length;
    }
    return n;
  }

  static Future<ChecklistData> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kKey);
      if (raw == null || raw.isEmpty) return ChecklistData(<String>{}, <CustomCheck>[]);
      final m = jsonDecode(raw);
      if (m is! Map) return ChecklistData(<String>{}, <CustomCheck>[]);
      final done = <String>{};
      final d = m['done'];
      if (d is List) {
        for (final e in d) {
          if (e is String) done.add(e);
        }
      }
      final custom = <CustomCheck>[];
      final c = m['custom'];
      if (c is List) {
        for (final e in c) {
          if (e is Map) {
            final id = e['id'];
            final t = e['t'];
            if (id is String && id.isNotEmpty && t is String && t.isNotEmpty) {
              custom.add(CustomCheck(id, t, e['d'] == true));
            }
          }
        }
      }
      return ChecklistData(done, custom);
    } catch (_) {
      return ChecklistData(<String>{}, <CustomCheck>[]);
    }
  }

  static Future<void> _save(ChecklistData d) async {
    final p = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'done': d.done.toList(),
      'custom': d.custom.map((e) => <String, dynamic>{'id': e.id, 't': e.text, 'd': e.done}).toList(),
    };
    await p.setString(_kKey, jsonEncode(map));
    _bump();
  }

  static Future<void> toggle(String id) async {
    final d = await load();
    final done = Set<String>.from(d.done);
    if (!done.remove(id)) done.add(id);
    await _save(ChecklistData(done, d.custom));
  }

  /// false = limit poori (30 items) ya text khali.
  static Future<bool> addCustom(String text) async {
    var t = text.trim();
    if (t.isEmpty) return false;
    if (t.length > maxText) t = t.substring(0, maxText);
    final d = await load();
    if (d.custom.length >= maxCustom) return false;
    final list = List<CustomCheck>.from(d.custom)
      ..add(CustomCheck(DateTime.now().microsecondsSinceEpoch.toString(), t, false));
    await _save(ChecklistData(d.done, list));
    return true;
  }

  static Future<void> toggleCustom(String id) async {
    final d = await load();
    final list = d.custom.map((e) => e.id == id ? CustomCheck(e.id, e.text, !e.done) : e).toList();
    await _save(ChecklistData(d.done, list));
  }

  static Future<void> deleteCustom(String id) async {
    final d = await load();
    final list = d.custom.where((e) => e.id != id).toList();
    await _save(ChecklistData(d.done, list));
  }

  /// Saare ticks hata deta hai (agli exam ke liye). Student ke apne items bane rehte hain.
  static Future<void> untickAll() async {
    final d = await load();
    final list = d.custom.map((e) => CustomCheck(e.id, e.text, false)).toList();
    await _save(ChecklistData(<String>{}, list));
  }

  /// Home tile ke liye: [tick kiye hue, kul items].
  static Future<List<int>> counts() async {
    final d = await load();
    final valid = <String>{};
    for (final g in kCheckGroups) {
      for (final it in g.items) {
        valid.add(it.id);
      }
    }
    final doneDefault = d.done.where(valid.contains).length;
    final doneCustom = d.custom.where((e) => e.done).length;
    return <int>[doneDefault + doneCustom, defaultTotal + d.custom.length];
  }
}
