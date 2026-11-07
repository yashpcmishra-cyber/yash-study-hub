import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  ExamTrackerStore - student ke exams ka tracker: form ki last date, exam ki
//  date, aur 3 checkbox (Form bhara / Fee di / Admit card). Sirf phone me
//  (SharedPreferences, key 'ysh5_exam_tracker'). Firestore ko 0 reads / 0 writes.
//  Cloud Backup me apne aap shamil.
// =============================================================================

class TrackedExam {
  final String id;
  final String name;
  final String formLast; // yyyy-MM-dd ya ''
  final String examDate; // yyyy-MM-dd ya ''
  final bool applied;
  final bool feePaid;
  final bool admitCard;
  final String note;

  const TrackedExam({
    required this.id,
    required this.name,
    this.formLast = '',
    this.examDate = '',
    this.applied = false,
    this.feePaid = false,
    this.admitCard = false,
    this.note = '',
  });

  TrackedExam copyWith({
    String? name,
    String? formLast,
    String? examDate,
    bool? applied,
    bool? feePaid,
    bool? admitCard,
    String? note,
  }) {
    return TrackedExam(
      id: id,
      name: name ?? this.name,
      formLast: formLast ?? this.formLast,
      examDate: examDate ?? this.examDate,
      applied: applied ?? this.applied,
      feePaid: feePaid ?? this.feePaid,
      admitCard: admitCard ?? this.admitCard,
      note: note ?? this.note,
    );
  }

  DateTime? get formDay => ExamTrackerStore.parseDay(formLast);
  DateTime? get examDay => ExamTrackerStore.parseDay(examDate);

  Map<String, dynamic> toMap() => {
        'id': id,
        'n': name,
        'f': formLast,
        'e': examDate,
        'a': applied,
        'p': feePaid,
        'c': admitCard,
        'x': note,
      };

  static TrackedExam? fromMap(dynamic m) {
    try {
      if (m is! Map) return null;
      final id = (m['id'] ?? '').toString();
      final name = (m['n'] ?? '').toString().trim();
      if (id.isEmpty || name.isEmpty) return null;
      return TrackedExam(
        id: id,
        name: name,
        formLast: (m['f'] ?? '').toString(),
        examDate: (m['e'] ?? '').toString(),
        applied: m['a'] == true,
        feePaid: m['p'] == true,
        admitCard: m['c'] == true,
        note: (m['x'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Home card ke liye chhota saar: kitne exam, aur sabse paas ki tareekh kaun si.
class ExamTrackSummary {
  final int count;
  final String nearName;
  final int nearDays; // aaj se kitne din baad
  final bool nearIsForm; // true = form ki last date, false = exam date
  const ExamTrackSummary(this.count, this.nearName, this.nearDays, this.nearIsForm);
  bool get hasNear => nearName.isNotEmpty;
}

class ExamTrackerStore {
  ExamTrackerStore._();

  static const _kList = 'ysh5_exam_tracker';
  static const int maxExams = 25;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  // ------------------------------------------------------------- dates

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseDay(String s) {
    if (s.length != 10) return null;
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// [d] aaj se kitne din door hai (aaj = 0, kal = 1, beeta kal = -1).
  static int daysUntil(DateTime d) {
    final now = DateTime.now();
    final a = DateTime.utc(now.year, now.month, now.day);
    final b = DateTime.utc(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  /// Is exam ki sabse paas ki aane wali tareekh (form last date jab tak form
  /// nahi bhara, aur exam date). Kuch aane wala na ho to null.
  static int? nextDays(TrackedExam e) {
    int? best;
    final f = e.formDay;
    if (f != null && !e.applied) {
      final n = daysUntil(f);
      if (n >= 0) best = n;
    }
    final x = e.examDay;
    if (x != null) {
      final n = daysUntil(x);
      if (n >= 0 && (best == null || n < best)) best = n;
    }
    return best;
  }

  /// Paas wale exam pehle; jinki koi aane wali date nahi wo naam se, sabse neeche.
  static List<TrackedExam> sorted(List<TrackedExam> list) {
    final out = List<TrackedExam>.from(list);
    out.sort((a, b) {
      final x = nextDays(a);
      final y = nextDays(b);
      if (x != null && y != null) return x.compareTo(y);
      if (x != null) return -1;
      if (y != null) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  // ----------------------------------------------------------- storage

  static Future<List<TrackedExam>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kList);
      if (raw == null || raw.isEmpty) return <TrackedExam>[];
      final v = jsonDecode(raw);
      if (v is! List) return <TrackedExam>[];
      final out = <TrackedExam>[];
      for (final m in v) {
        final e = TrackedExam.fromMap(m);
        if (e != null) out.add(e);
      }
      return out;
    } catch (_) {
      return <TrackedExam>[];
    }
  }

  static Future<void> _write(List<TrackedExam> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kList, jsonEncode(list.map((e) => e.toMap()).toList()));
    _bump();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Naya jodta hai ya purana badalta hai. Limit (25) poori ho to false.
  static Future<bool> save(TrackedExam e) async {
    try {
      final list = await all();
      final i = list.indexWhere((x) => x.id == e.id);
      if (i >= 0) {
        list[i] = e;
      } else {
        if (list.length >= maxExams) return false;
        list.add(e);
      }
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

  static Future<ExamTrackSummary> summary() async {
    final list = await all();
    var name = '';
    var days = 0;
    var isForm = false;
    var found = false;
    for (final e in list) {
      final f = e.formDay;
      if (f != null && !e.applied) {
        final n = daysUntil(f);
        if (n >= 0 && (!found || n < days)) {
          found = true;
          name = e.name;
          days = n;
          isForm = true;
        }
      }
      final x = e.examDay;
      if (x != null) {
        final n = daysUntil(x);
        if (n >= 0 && (!found || n < days)) {
          found = true;
          name = e.name;
          days = n;
          isForm = false;
        }
      }
    }
    return ExamTrackSummary(list.length, name, days, isForm);
  }
}
