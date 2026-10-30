import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// One exam or subject folder (id, name and emoji come from Firestore).
class FreeMcqChoice {
  final String id;
  final String name;
  final String emoji;
  const FreeMcqChoice(this.id, this.name, this.emoji);
}

/// The built-in "English" folder (Banking PO / Clerk English, easy + moderate + hard, ONE new set every week).
/// It holds ONE subject (english) and no Static GK / Science / GS; every other exam folder keeps its 3 subjects.
const String kEnglishFolderId = 'english';
const FreeMcqChoice kEnglishFolder = FreeMcqChoice(kEnglishFolderId, 'English', '📖');

/// One practice set (a month for GK / Science / GS, a week for English). Only the metadata; the questions are read when opened.
class FreeMcqSetMeta {
  final String id;
  final String examId;
  final String subjectId;
  final String monthKey; // yyyy-MM
  final String weekKey; // "2026-W44", only for weekly English sets
  final String periodStart; // yyyy-MM-dd (the Monday), only for weekly English sets
  final int count;
  final String source;

  const FreeMcqSetMeta({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.monthKey,
    required this.count,
    required this.source,
    this.weekKey = '',
    this.periodStart = '',
  });

  /// yyyy-MM-dd used to sort sets and to decide how old a set is.
  String get startKey => periodStart.isNotEmpty ? periodStart : '$monthKey-01';

  Map<String, dynamic> toMap() => {
        'id': id,
        'examId': examId,
        'subjectId': subjectId,
        'monthKey': monthKey,
        'weekKey': weekKey,
        'periodStart': periodStart,
        'count': count,
        'source': source,
      };

  factory FreeMcqSetMeta.fromMap(Map<String, dynamic> m) => FreeMcqSetMeta(
        id: (m['id'] ?? '').toString(),
        examId: (m['examId'] ?? '').toString(),
        subjectId: (m['subjectId'] ?? '').toString(),
        monthKey: (m['monthKey'] ?? '').toString(),
        weekKey: (m['weekKey'] ?? '').toString(),
        periodStart: (m['periodStart'] ?? '').toString(),
        count: (m['count'] as num?)?.toInt() ?? 0,
        source: (m['source'] ?? '').toString(),
      );
}

/// A source page of a set (older Current Affairs sets had one: the PIB link).
class FreeMcqSource {
  final String title;
  final String url;
  const FreeMcqSource(this.title, this.url);
}

/// The questions of one set plus where they came from.
class FreeMcqSet {
  final List<MockQuestion> questions;
  final List<FreeMcqSource> sources;
  final String license; // "Original questions" or "Source: PIB, Government of India"
  final String licenseUrl;
  const FreeMcqSet(this.questions, {this.sources = const [], this.license = '', this.licenseUrl = ''});
}

/// Everything the Free MCQs screens need, from one small document.
class FreeMcqIndex {
  final List<FreeMcqChoice> exams;
  final List<FreeMcqChoice> subjects;
  final List<FreeMcqSetMeta> sets;

  const FreeMcqIndex(this.exams, this.subjects, this.sets);

  /// Subject folders of one exam: the English folder has only English, the other exams never show English.
  List<FreeMcqChoice> subjectsForExam(String examId) => examId == kEnglishFolderId
      ? subjects.where((s) => s.id == kEnglishFolderId).toList()
      : subjects.where((s) => s.id != kEnglishFolderId).toList();

  /// All sets of one exam, newest month first.
  List<FreeMcqSetMeta> setsForExam(String examId) => sets.where((s) => s.examId == examId).toList()..sort(_newestFirst);

  /// Sets of one exam + subject, newest month first.
  List<FreeMcqSetMeta> setsFor(String examId, String subjectId) =>
      sets.where((s) => s.examId == examId && s.subjectId == subjectId).toList()..sort(_newestFirst);

  static int _newestFirst(FreeMcqSetMeta a, FreeMcqSetMeta b) => b.startKey.compareTo(a.startKey);
}

/// Free MCQs data, with a phone cache so Firestore is read as little as possible.
///
/// Firestore layout (GK / Science / GS written monthly by fetch-free-mcqs.js, English weekly by fetch-free-english.js):
///   freeMcqIndex/current          1 doc, read at most once every 12 hours per phone
///   freeMcqSets/{set id}          1 doc per exam+subject+month (English: per week), read ONCE per phone, then cached
///
/// Retention: Firestore deletes a weekly English set 2 months after its week began, but a set the student has
/// opened stays on the phone for 3 months (see [_withCachedSets]), so old weeks keep working and cost no reads.
///
/// Quiz scores stay on the phone only (no Firestore writes at all for this feature).
class FreeMcqService {
  static const _kIndex = 'ysh_fmcq_index_v2';
  static const _kSetPrefix = 'ysh_fmcq_set_v2_';
  static const _kSetIds = 'ysh_fmcq_set_ids_v2'; // cached set ids, oldest first
  static const _kSetMeta = 'ysh_fmcq_set_meta_v1'; // {setId: meta} of the cached sets, to list them after Firestore deleted them
  static const _kDone = 'ysh_fmcq_done_v1'; // {setId: "correct/total"}
  static const Duration _indexTtl = Duration(hours: 12);
  static const int _maxCachedSets = 60; // safety cap (a set is about 20-30 KB)
  static const int _keepCachedMonths = 3; // a cached set that left Firestore stays this long on the phone

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final _db = FirebaseFirestore.instance;

  /// "2026-10" -> "October 2026".
  static String monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return key;
    return '${_months[m - 1]} ${parts[0]}';
  }

  /// The name of a set on a tile: "October 2026" for a monthly set, "Week 44 · 26 Oct – 1 Nov 2026" for a weekly one.
  static String setLabel(FreeMcqSetMeta m) {
    final start = DateTime.tryParse(m.periodStart);
    if (start == null) return monthLabel(m.monthKey);
    final end = DateTime(start.year, start.month, start.day + 6);
    final startText = '${start.day} ${_shortMonths[start.month - 1]}${start.year != end.year ? ' ${start.year}' : ''}';
    final range = '$startText – ${end.day} ${_shortMonths[end.month - 1]} ${end.year}';
    final week = int.tryParse(RegExp(r'W(\d+)$').firstMatch(m.weekKey)?.group(1) ?? '');
    return week == null ? range : 'Week $week · $range';
  }

  // ------------------------------------------------------------ index

  Future<FreeMcqIndex?> loadIndex({bool force = false}) async {
    final p = await SharedPreferences.getInstance();
    final cached = _readIndexCache(p);
    final fresh = cached != null && DateTime.now().millisecondsSinceEpoch - cached.at < _indexTtl.inMilliseconds;
    if (!force && fresh) return _withCachedSets(p, cached.index);

    try {
      final snap = await _db.collection('freeMcqIndex').doc('current').get().timeout(const Duration(seconds: 12));
      final data = snap.data();
      if (data == null) {
        if (cached == null) return null;
        return _withCachedSets(p, cached.index);
      }
      final json = <String, dynamic>{'exams': data['exams'], 'subjects': data['subjects'], 'sets': data['sets']};
      await p.setString(_kIndex, jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, ...json}));
      return _withCachedSets(p, _fromMap(json));
    } catch (_) {
      // No internet or no permission: show what we already have, if anything.
      if (cached != null) return _withCachedSets(p, cached.index);
      rethrow;
    }
  }

  static ({int at, FreeMcqIndex index})? _readIndexCache(SharedPreferences p) {
    final raw = p.getString(_kIndex);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (at: (m['at'] as num?)?.toInt() ?? 0, index: _fromMap(m));
    } catch (_) {
      return null;
    }
  }

  // Current Affairs monthly quizzes are not made any more, so the subject is
  // hidden here even if an older index (or phone cache) still lists it.
  static const Set<String> _removedSubjectIds = {'ca'};

  static FreeMcqIndex _fromMap(Map<String, dynamic> m) {
    final sets = <FreeMcqSetMeta>[];
    final raw = m['sets'];
    if (raw is List) {
      for (final e in raw.whereType<Map>()) {
        final meta = FreeMcqSetMeta.fromMap(Map<String, dynamic>.from(e));
        if (meta.id.isNotEmpty && meta.examId.isNotEmpty && meta.subjectId.isNotEmpty && !_removedSubjectIds.contains(meta.subjectId)) {
          sets.add(meta);
        }
      }
    }
    final subjects = _choices(m['subjects']).where((s) => !_removedSubjectIds.contains(s.id)).toList();
    // The English folder is built in: it shows even before the first monthly run has added it to the index.
    final exams = [..._choices(m['exams'])];
    if (!exams.any((e) => e.id == kEnglishFolderId)) exams.add(kEnglishFolder);
    if (!subjects.any((s) => s.id == kEnglishFolderId)) subjects.add(kEnglishFolder);
    return FreeMcqIndex(exams, subjects, sets);
  }

  static List<FreeMcqChoice> _choices(dynamic raw) {
    if (raw is! List) return const [];
    final out = <FreeMcqChoice>[];
    for (final e in raw.whereType<Map>()) {
      final m = Map<String, dynamic>.from(e);
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) continue;
      out.add(FreeMcqChoice(id, (m['name'] ?? '').toString(), (m['emoji'] ?? '').toString()));
    }
    return out;
  }

  // ------------------------------------------------------------ one set

  /// One month's set (questions + sources). Reads Firestore only the first time on this phone.
  Future<FreeMcqSet> loadSet(FreeMcqSetMeta meta) async {
    final p = await SharedPreferences.getInstance();
    final key = '$_kSetPrefix${meta.id}';
    final cached = _setFromJson(p.getString(key));
    if (cached != null) return cached;

    final snap = await _db.collection('freeMcqSets').doc(meta.id).get().timeout(const Duration(seconds: 15));
    final data = snap.data();
    final set = data == null ? null : _setFromData(data);
    if (set == null) throw StateError('This set is not available yet.');

    await p.setString(
      key,
      jsonEncode({
        'questions': set.questions.map((q) => q.toMap()).toList(),
        'sources': [for (final s in set.sources) {'title': s.title, 'url': s.url}],
        'license': set.license,
        'licenseUrl': set.licenseUrl,
      }),
    );
    await _rememberSetId(p, meta.id);
    await _rememberSetMeta(p, meta);
    return set;
  }

  static FreeMcqSet? _setFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return _setFromData(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static FreeMcqSet? _setFromData(Map<String, dynamic> data) {
    final qs = _questionsFromData(data['questions']);
    if (qs == null) return null;
    final sources = <FreeMcqSource>[];
    final raw = data['sources'];
    if (raw is List) {
      for (final e in raw.whereType<Map>()) {
        final title = (e['title'] ?? '').toString().trim();
        final url = (e['url'] ?? '').toString().trim();
        if (title.isNotEmpty) sources.add(FreeMcqSource(title, url));
      }
    }
    return FreeMcqSet(
      qs,
      sources: sources,
      license: (data['license'] ?? '').toString(),
      licenseUrl: (data['licenseUrl'] ?? '').toString(),
    );
  }

  /// Keeps only well-formed questions (4 options, valid answer index).
  static List<MockQuestion>? _questionsFromData(dynamic raw) {
    if (raw is! List) return null;
    final out = <MockQuestion>[];
    for (final e in raw.whereType<Map>()) {
      final q = MockQuestion.fromMap(Map<String, dynamic>.from(e));
      if (q.text.trim().isEmpty || q.options.length != 4) continue;
      if (q.correctIndex < 0 || q.correctIndex > 3) continue;
      out.add(q);
    }
    return out.isEmpty ? null : out;
  }

  /// Phone cache: keep the newest [_maxCachedSets] sets only.
  static Future<void> _rememberSetId(SharedPreferences p, String id) async {
    final ids = List<String>.from(p.getStringList(_kSetIds) ?? const <String>[])..remove(id)..add(id);
    final metas = _readMetaMap(p);
    while (ids.length > _maxCachedSets) {
      final old = ids.removeAt(0);
      await p.remove('$_kSetPrefix$old');
      metas.remove(old);
    }
    await p.setStringList(_kSetIds, ids);
    await p.setString(_kSetMeta, jsonEncode(metas));
  }

  static Future<void> _rememberSetMeta(SharedPreferences p, FreeMcqSetMeta meta) async {
    final metas = _readMetaMap(p);
    metas[meta.id] = meta.toMap();
    await p.setString(_kSetMeta, jsonEncode(metas));
  }

  static Map<String, dynamic> _readMetaMap(SharedPreferences p) {
    final raw = p.getString(_kSetMeta);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// yyyy-MM-dd, [_keepCachedMonths] months ago. A cached set that started before this is removed.
  static String _cacheCutoff() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month - _keepCachedMonths, n.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Merges the sets cached on this phone into the Firestore index.
  ///  - a cached set that is still in the index: kept as before;
  ///  - a cached set Firestore has already deleted (weekly English sets go after 2 months): still listed for
  ///    [_keepCachedMonths] months, opened from the phone with no Firestore read;
  ///  - anything older, or a cache entry we know nothing about: removed from the phone.
  static Future<FreeMcqIndex> _withCachedSets(SharedPreferences p, FreeMcqIndex index) async {
    final inIndex = index.sets.map((s) => s.id).toSet();
    final ids = p.getStringList(_kSetIds) ?? <String>[];
    final metas = _readMetaMap(p);
    final cutoff = _cacheCutoff();
    final keptIds = <String>[];
    final extras = <FreeMcqSetMeta>[];
    for (final id in ids) {
      if (inIndex.contains(id)) {
        keptIds.add(id);
        continue;
      }
      final raw = metas[id];
      final meta = raw is Map ? FreeMcqSetMeta.fromMap(Map<String, dynamic>.from(raw)) : null;
      final valid = meta != null &&
          meta.examId.isNotEmpty &&
          meta.subjectId.isNotEmpty &&
          !_removedSubjectIds.contains(meta.subjectId) &&
          meta.startKey.compareTo(cutoff) >= 0 &&
          p.containsKey('$_kSetPrefix$id');
      if (valid) {
        keptIds.add(id);
        extras.add(meta);
      } else {
        await p.remove('$_kSetPrefix$id');
        metas.remove(id);
      }
    }
    if (keptIds.length != ids.length) {
      await p.setStringList(_kSetIds, keptIds);
      await p.setString(_kSetMeta, jsonEncode(metas));
    }
    if (extras.isEmpty) return index;
    return FreeMcqIndex(index.exams, index.subjects, [...index.sets, ...extras]);
  }

  // ------------------------------------------------------------ scores (phone only)

  /// setId -> "correct/total" for every set the student has finished on this phone.
  Future<Map<String, String>> doneScores() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDone);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> markDone(String setId, int correct, int total) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDone);
    final m = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        m.addAll(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    m[setId] = '$correct/$total';
    await p.setString(_kDone, jsonEncode(m));
  }
}
