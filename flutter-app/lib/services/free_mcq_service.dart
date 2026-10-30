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

/// The built-in "English" folder (Banking PO / Clerk English, one set per month).
/// It holds ONE subject (english) and no Static GK / Science / GS; every other exam folder keeps its 3 subjects.
const String kEnglishFolderId = 'english';
const FreeMcqChoice kEnglishFolder = FreeMcqChoice(kEnglishFolderId, 'English', '📖');

/// One month's practice set. Only the metadata; the questions are read when opened.
class FreeMcqSetMeta {
  final String id;
  final String examId;
  final String subjectId;
  final String monthKey; // yyyy-MM
  final int count;
  final String source;

  const FreeMcqSetMeta({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.monthKey,
    required this.count,
    required this.source,
  });

  factory FreeMcqSetMeta.fromMap(Map<String, dynamic> m) => FreeMcqSetMeta(
        id: (m['id'] ?? '').toString(),
        examId: (m['examId'] ?? '').toString(),
        subjectId: (m['subjectId'] ?? '').toString(),
        monthKey: (m['monthKey'] ?? '').toString(),
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

  static int _newestFirst(FreeMcqSetMeta a, FreeMcqSetMeta b) => b.monthKey.compareTo(a.monthKey);
}

/// Free MCQs data, with a phone cache so Firestore is read as little as possible.
///
/// Firestore layout (written monthly by production-app-guide/free-scripts/fetch-free-mcqs.js):
///   freeMcqIndex/current          1 doc, read at most once every 12 hours per phone
///   freeMcqSets/{set id}          1 doc per exam+subject+month, read ONCE per phone, then cached
///
/// Quiz scores stay on the phone only (no Firestore writes at all for this feature).
class FreeMcqService {
  static const _kIndex = 'ysh_fmcq_index_v2';
  static const _kSetPrefix = 'ysh_fmcq_set_v2_';
  static const _kSetIds = 'ysh_fmcq_set_ids_v2'; // cached set ids, oldest first
  static const _kDone = 'ysh_fmcq_done_v1'; // {setId: "correct/total"}
  static const Duration _indexTtl = Duration(hours: 12);
  static const int _maxCachedSets = 12;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  final _db = FirebaseFirestore.instance;

  /// "2026-10" -> "October 2026".
  static String monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return key;
    return '${_months[m - 1]} ${parts[0]}';
  }

  // ------------------------------------------------------------ index

  Future<FreeMcqIndex?> loadIndex({bool force = false}) async {
    final p = await SharedPreferences.getInstance();
    final cached = _readIndexCache(p);
    final fresh = cached != null && DateTime.now().millisecondsSinceEpoch - cached.at < _indexTtl.inMilliseconds;
    if (!force && fresh) return cached.index;

    try {
      final snap = await _db.collection('freeMcqIndex').doc('current').get().timeout(const Duration(seconds: 12));
      final data = snap.data();
      if (data == null) return cached?.index;
      final json = <String, dynamic>{'exams': data['exams'], 'subjects': data['subjects'], 'sets': data['sets']};
      await p.setString(_kIndex, jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, ...json}));
      final index = _fromMap(json);
      await _dropCachedSetsNotIn(p, index.sets.map((s) => s.id).toSet());
      return index;
    } catch (_) {
      // No internet or no permission: show what we already have, if anything.
      if (cached != null) return cached.index;
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
    while (ids.length > _maxCachedSets) {
      final old = ids.removeAt(0);
      await p.remove('$_kSetPrefix$old');
    }
    await p.setStringList(_kSetIds, ids);
  }

  /// Removes cached sets that are no longer in the index (older than the kept months).
  static Future<void> _dropCachedSetsNotIn(SharedPreferences p, Set<String> keep) async {
    final ids = p.getStringList(_kSetIds) ?? <String>[];
    final kept = <String>[];
    for (final id in ids) {
      if (keep.contains(id)) {
        kept.add(id);
      } else {
        await p.remove('$_kSetPrefix$id');
      }
    }
    if (kept.length != ids.length) await p.setStringList(_kSetIds, kept);
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
