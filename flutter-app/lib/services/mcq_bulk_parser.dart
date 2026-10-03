import '../models/models.dart';

// Reads a block of pasted MCQs (admin "Bulk paste") and turns it into
// MockQuestion objects. Pure Dart: it touches no screen and no Firebase.
//
// Format (one question after another, blank lines are optional):
//
//   Q: English question || हिंदी प्रश्न
//   A: English option || हिंदी विकल्प
//   B: ...
//   C: ...
//   D: ...
//   ANS: B
//   EXP: English explanation || हिंदी व्याख्या      <- optional
//
// "||" splits English from Hindi. Without "||" the text is a single language.

/// Questions allowed in ONE paste.
const int kBulkMinQuestions = 10;
const int kBulkMaxQuestions = 100;

/// Safety cap for one whole test (keeps the Firestore document small enough).
const int kMaxQuestionsPerTest = 200;

/// Text the admin can copy and fill in.
const String kBulkTemplate = '''Q: What is the capital of India? || भारत की राजधानी क्या है?
A: Mumbai || मुंबई
B: Delhi || दिल्ली
C: Kolkata || कोलकाता
D: Chennai || चेन्नई
ANS: B
EXP: Delhi is the capital of India. || दिल्ली भारत की राजधानी है।

Q: Which planet is called the Red Planet? || किस ग्रह को लाल ग्रह कहा जाता है?
A: Venus || शुक्र
B: Mars || मंगल
C: Jupiter || बृहस्पति
D: Saturn || शनि
ANS: B
EXP: Mars looks red because of iron oxide. || मंगल लौह ऑक्साइड के कारण लाल दिखता है।
''';

class McqParseResult {
  final List<MockQuestion> questions;
  final List<String> errors;
  final int blocksFound;
  const McqParseResult(this.questions, this.errors, this.blocksFound);

  /// True only when every question is valid AND the count is 10 to 100.
  bool get ok => errors.isEmpty;
}

class _Draft {
  final Map<String, String> f = {};
  String lastKey = '';
  int? ans;
  String? ansRaw;
}

final RegExp _qRe = RegExp(r'^(?:Q|QUESTION)\s*\d*\s*[:.)\-]\s*(.*)$', caseSensitive: false);
final RegExp _optRe = RegExp(r'^\(?([A-Da-d])\s*[:.)]\s*(.*)$');
final RegExp _ansRe = RegExp(r'^(?:ANS|ANSWER)\s*[:.)\-]\s*(.*)$', caseSensitive: false);
final RegExp _expRe = RegExp(r'^(?:EXP|EXPLANATION)\s*[:.)\-]\s*(.*)$', caseSensitive: false);
final RegExp _alnum = RegExp(r'[A-Za-z0-9]');

List<String> _split(String v) {
  final i = v.indexOf('||');
  if (i < 0) return [v.trim(), ''];
  return [v.substring(0, i).trim(), v.substring(i + 2).replaceAll('||', ' ').trim()];
}

void _put(_Draft d, String key, String value) {
  final parts = _split(value);
  d.f[key] = parts[0];
  if (parts[1].isNotEmpty) {
    d.f['${key}h'] = parts[1];
    d.lastKey = '${key}h';
  } else {
    d.lastKey = key;
  }
}

// A line that matches no label belongs to the previous field (long text
// that wrapped onto the next line).
void _append(_Draft d, String line) {
  if (d.lastKey.isEmpty) return;
  final old = d.f[d.lastKey] ?? '';
  d.f[d.lastKey] = old.isEmpty ? line : '$old\n$line';
}

int? _parseAns(String v) {
  var s = v.trim();
  while (s.isNotEmpty && (s[0] == '(' || s[0] == ' ')) {
    s = s.substring(1);
  }
  if (s.isEmpty) return null;
  final c = s[0].toUpperCase();
  var idx = 'ABCD'.indexOf(c);
  if (idx < 0) {
    final n = int.tryParse(c);
    if (n != null && n >= 1 && n <= 4) idx = n - 1;
  }
  if (idx < 0) return null;
  // "B" or "B)" or "B) Delhi" are fine; a word such as "Banana" is not.
  if (s.length > 1 && _alnum.hasMatch(s[1])) return null;
  return idx;
}

String _short(String s) {
  final t = s.replaceAll('\n', ' ').trim();
  if (t.isEmpty) return '';
  return ' ("${t.length > 28 ? '${t.substring(0, 28)}...' : t}")';
}

McqParseResult parseBulkMcqs(String raw) {
  final lines = raw.replaceAll('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final drafts = <_Draft>[];
  final errors = <String>[];
  _Draft? cur;
  var strayReported = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final q = _qRe.firstMatch(line);
    if (q != null) {
      cur = _Draft();
      drafts.add(cur);
      _put(cur, 'q', q.group(1) ?? '');
      continue;
    }
    if (cur == null) {
      if (!strayReported) {
        errors.add('Text found before the first question. Every question must start with "Q:".');
        strayReported = true;
      }
      continue;
    }
    final a = _ansRe.firstMatch(line);
    if (a != null) {
      final v = a.group(1) ?? '';
      cur.ansRaw = v;
      cur.ans = _parseAns(v);
      cur.lastKey = '';
      continue;
    }
    final e = _expRe.firstMatch(line);
    if (e != null) {
      _put(cur, 'e', e.group(1) ?? '');
      continue;
    }
    final o = _optRe.firstMatch(line);
    if (o != null) {
      final idx = 'ABCD'.indexOf((o.group(1) ?? 'A').toUpperCase());
      _put(cur, 'o$idx', o.group(2) ?? '');
      continue;
    }
    _append(cur, line);
  }

  final questions = <MockQuestion>[];
  for (var i = 0; i < drafts.length; i++) {
    final d = drafts[i];
    final problems = <String>[];

    var qEn = d.f['q'] ?? '';
    var qHi = d.f['qh'] ?? '';
    if (qEn.isEmpty && qHi.isNotEmpty) {
      qEn = qHi;
      qHi = '';
    }
    if (qEn.isEmpty) problems.add('question text is empty');

    final optEn = <String>[];
    final optHi = <String>[];
    for (var k = 0; k < 4; k++) {
      var en = d.f['o$k'] ?? '';
      var hi = d.f['o${k}h'] ?? '';
      if (en.isEmpty && hi.isNotEmpty) {
        en = hi;
        hi = '';
      }
      if (en.isEmpty) problems.add('option ${'ABCD'[k]} is missing');
      optEn.add(en);
      optHi.add(hi);
    }

    if (d.ans == null) {
      problems.add(d.ansRaw == null ? 'ANS line is missing' : 'ANS is not valid (write A, B, C or D)');
    }

    var eEn = d.f['e'] ?? '';
    var eHi = d.f['eh'] ?? '';
    if (eEn.isEmpty && eHi.isNotEmpty) {
      eEn = eHi;
      eHi = '';
    }

    if (problems.isNotEmpty) {
      errors.add('Q${i + 1}${_short(qEn)}: ${problems.join(', ')}');
      continue;
    }

    questions.add(MockQuestion(
      text: qEn,
      options: optEn,
      correctIndex: d.ans ?? 0,
      textHi: qHi,
      // Hindi options are used only when all four are present.
      optionsHi: optHi.every((s) => s.isNotEmpty) ? optHi : const [],
      explanation: eEn,
      explanationHi: eHi,
    ));
  }

  if (drafts.isEmpty) {
    errors.add('No question found. Every question must start with "Q:".');
  } else if (drafts.length < kBulkMinQuestions || drafts.length > kBulkMaxQuestions) {
    errors.insert(0, 'One paste must have $kBulkMinQuestions to $kBulkMaxQuestions questions (found ${drafts.length}).');
  }

  return McqParseResult(questions, errors, drafts.length);
}
