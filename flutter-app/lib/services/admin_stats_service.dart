import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin Panel > Stats ke liye saare counts yahin se aate hain.
///
/// KAM READS ka tarika:
///  * Sab kuch Firestore ke server-side count() se hota hai (1 read ~ 1000 docs),
///    koi student document download nahi hota.
///  * Beete hue din (kal, parso ...) ek baar ginne ke baad phone mein save ho
///    jaate hain - dobara Firestore se nahi poochhe jaate.
///  * Aaj ke numbers 5 minute tak cache rehte hain; Refresh dabane par naye aate hain.
///
/// "Kal" ka number pehle galat aata tha, kyunki student ke document mein sirf
/// AAKHRI khulne ka din (lastAppDay) rehta tha. Aaj khulte hi student "kal" se
/// hat jaata tha. Ab har din ka alag nishaan (appDays.d20261125 = true) rehta hai.
class DayStats {
  final int app, appPhone, appTablet, web, webPhone, webTablet, webComputer, both;
  const DayStats({
    this.app = 0,
    this.appPhone = 0,
    this.appTablet = 0,
    this.web = 0,
    this.webPhone = 0,
    this.webTablet = 0,
    this.webComputer = 0,
    this.both = 0,
  });

  /// Alag-alag students (jo App aur Web dono par aaye unhe ek hi ginte hain).
  int get unique => (app + web - both).clamp(0, 1 << 30).toInt();

  List<int> toList() => [app, appPhone, appTablet, web, webPhone, webTablet, webComputer, both];

  factory DayStats.fromList(List<dynamic> l) {
    int g(int i) => i < l.length ? (l[i] as num).toInt() : 0;
    return DayStats(
      app: g(0),
      appPhone: g(1),
      appTablet: g(2),
      web: g(3),
      webPhone: g(4),
      webTablet: g(5),
      webComputer: g(6),
      both: g(7),
    );
  }
}

/// Ek din ki row (trend ke liye). [stats] null = us din ka data nahi mila.
class DayRow {
  final String day; // yyyy-MM-dd
  final DateTime date;
  final DayStats? stats;
  const DayRow(this.day, this.date, this.stats);
}

class StatsBundle {
  final DayStats today;
  final DayStats yesterday;
  final List<DayRow> trend; // purana -> naya, aakhri = aaj (7 din)
  final DateTime fetchedAt;
  const StatsBundle(this.today, this.yesterday, this.trend, this.fetchedAt);
}

class AdminStatsService {
  AdminStatsService._();

  /// Is session mein kitne count() query chale (lagbhag utne hi reads).
  static int reads = 0;

  static final _students = FirebaseFirestore.instance.collection('students');

  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// 2026-11-26 -> d20261126 (map ke andar field ka naam; app aur web dono yahi likhte hain).
  static String dayField(String day) => 'd${day.replaceAll('-', '')}';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime daysAgo(int n) {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day - n);
  }

  static Future<int> _cnt(Query<Map<String, dynamic>> q) async {
    reads++;
    final agg = await q.count().get();
    return agg.count ?? 0;
  }

  // students.{map}.{dYYYYMMDD} == true
  static Query<Map<String, dynamic>> _hist(String map, String day) =>
      _students.where(FieldPath([map, dayField(day)]), isEqualTo: true);

  // students.{field} == 'yyyy-MM-dd'   (purana "aakhri din" field)
  static Query<Map<String, dynamic>> _last(String field, String day) => _students.where(field, isEqualTo: day);

  static int _max(int a, int b) => a > b ? a : b;

  /// Poora ek din: App (total/phone/tablet), Web (total/phone/tablet/computer), dono.
  /// Aaj ke liye purane "last day" fields kaafi hain (aaj ke liye wo bilkul sahi hote hain).
  /// Beete din ke liye history aur purane fields dono dekh kar bada number liya jaata hai
  /// (jab tak sab students naya app / naya web na chala len).
  static Future<DayStats> full(String day, {required bool isToday}) async {
    Future<int> c(String histMap, String lastField) async {
      if (isToday) return _cnt(_last(lastField, day));
      final r = await Future.wait([_cnt(_hist(histMap, day)), _cnt(_last(lastField, day))]);
      return _max(r[0], r[1]);
    }

    final r = await Future.wait([
      c('appDays', 'lastAppDay'),
      c('appPhoneDays', 'lastAppPhoneDay'),
      c('appTabletDays', 'lastAppTabletDay'),
      c('webDays', 'lastWebDay'),
      c('webPhoneDays', 'lastWebPhoneDay'),
      c('webTabletDays', 'lastWebTabletDay'),
      c('webComputerDays', 'lastWebComputerDay'),
      _bothLegacy(day),
      if (!isToday) _bothHist(day),
    ]);
    var both = r[7];
    if (!isToday) both = _max(both, r[8]);
    final app = r[0], web = r[3];
    both = both.clamp(0, app < web ? app : web).toInt();
    return DayStats(
      app: app,
      appPhone: r[1],
      appTablet: r[2],
      web: web,
      webPhone: r[4],
      webTablet: r[5],
      webComputer: r[6],
      both: both,
    );
  }

  static Future<int> _bothLegacy(String day) =>
      _cnt(_students.where('lastAppDay', isEqualTo: day).where('lastWebDay', isEqualTo: day));

  static Future<int> _bothHist(String day) =>
      _cnt(_hist('appDays', day).where(FieldPath(['webDays', dayField(day)]), isEqualTo: true));

  /// Halka version (6 reads): App, Web, dono. Trend aur "koi bhi date" ke liye.
  /// Web sirf "aakhri din" save karta hai, isliye Web ke beete din asli se kam ho sakte hain.
  static Future<DayStats> lite(String day) async {
    final r = await Future.wait([
      _cnt(_hist('appDays', day)),
      _cnt(_last('lastAppDay', day)),
      _cnt(_hist('webDays', day)),
      _cnt(_last('lastWebDay', day)),
      _bothHist(day),
      _bothLegacy(day),
    ]);
    final app = _max(r[0], r[1]);
    final web = _max(r[2], r[3]);
    final both = _max(r[4], r[5]).clamp(0, app < web ? app : web).toInt();
    return DayStats(app: app, web: web, both: both);
  }

  // ------------------------------------------------------------------
  // Phone mein cache
  // ------------------------------------------------------------------
  static Future<List<int>?> _readCache(String key, {Duration? maxAge}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final t = DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt());
      if (maxAge != null && DateTime.now().difference(t) > maxAge) return null;
      return (m['v'] as List).map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> _cacheTime(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(String key, List<int> v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'v': v}));
    } catch (_) {}
  }

  /// Chhote number-list ka cache (registered / active / installs / windows).
  static Future<List<int>> cachedInts(
    String key,
    Future<List<int>> Function() fetch, {
    Duration ttl = const Duration(minutes: 10),
    bool force = false,
  }) async {
    if (!force) {
      final hit = await _readCache('ast_$key', maxAge: ttl);
      if (hit != null) return hit;
    }
    final v = await fetch();
    await _writeCache('ast_$key', v);
    return v;
  }

  /// Beeta hua din: ek baar gin kar hamesha ke liye phone mein. Sirf tab save hota hai jab
  /// ginti us din ke KHATAM hone ke baad hui ho (warna adhura number save ho jaata).
  static Future<DayStats> _past(DateTime date, {required bool fullCount, required bool force}) async {
    final day = dayKey(date);
    final key = 'ast2_${day}_${fullCount ? 'f' : 'l'}';
    if (!force) {
      final hit = await _readCache(key);
      final at = await _cacheTime(key);
      if (hit != null && at != null && _dayOnly(at).isAfter(_dayOnly(date))) return DayStats.fromList(hit);
    }
    final s = fullCount ? await full(day, isToday: false) : await lite(day);
    final endedAlready = _dayOnly(DateTime.now()).isAfter(_dayOnly(date));
    if (endedAlready) await _writeCache(key, s.toList());
    return s;
  }

  /// Aaj + kal + pichhle 7 din ka trend. [forceAll] = sab din dobara ginna.
  static Future<StatsBundle> loadBundle({bool force = false, bool forceAll = false}) async {
    final todayDate = daysAgo(0);
    final todayKey = dayKey(todayDate);

    // Aaj: 5 minute cache (force par naya).
    DayStats today;
    final cachedToday = force ? null : await _readCache('ast2_today_$todayKey', maxAge: const Duration(minutes: 5));
    if (cachedToday != null) {
      today = DayStats.fromList(cachedToday);
    } else {
      today = await full(todayKey, isToday: true);
      await _writeCache('ast2_today_$todayKey', today.toList());
    }

    final yesterday = await _past(daysAgo(1), fullCount: true, force: forceAll);

    final older = await Future.wait([
      for (var i = 6; i >= 2; i--) _past(daysAgo(i), fullCount: false, force: forceAll),
    ]);

    final rows = <DayRow>[
      for (var i = 0; i < older.length; i++) DayRow(dayKey(daysAgo(6 - i)), daysAgo(6 - i), older[i]),
      DayRow(dayKey(daysAgo(1)), daysAgo(1), yesterday),
      DayRow(todayKey, todayDate, today),
    ];
    final at = await _cacheTime('ast2_today_$todayKey') ?? DateTime.now();
    return StatsBundle(today, yesterday, rows, at);
  }

  /// Koi bhi ek date (pichhle 45 din ke andar).
  static Future<DayStats> forDate(DateTime d) async {
    final date = _dayOnly(d);
    final diff = _dayOnly(DateTime.now()).difference(date).inDays;
    if (diff <= 0) return full(dayKey(date), isToday: true);
    return _past(date, fullCount: diff == 1, force: false);
  }

  /// [unique7, app7, web7, unique30, app30, web30] - itne alag students pichhle 7 / 30 din mein aaye.
  /// "Aakhri baar kab khola" (lastSeenDay / lastAppDay / lastWebDay) se, isliye ye bilkul sahi hai.
  static Future<List<int>> windows() async {
    Future<List<int>> one(int back) async {
      final since = dayKey(daysAgo(back));
      Future<int> g(String f) => _cnt(_students.where(f, isGreaterThanOrEqualTo: since));
      final r = await Future.wait([g('lastSeenDay'), g('lastAppDay'), g('lastWebDay')]);
      final unique = _max(r[0], _max(r[1], r[2]));
      return [unique, r[1], r[2]];
    }

    final a = await one(6);
    final b = await one(29);
    return [...a, ...b];
  }
}
