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
//
// REASONING format (used only when the subject is Reasoning, see
// isReasoningSubject): the same Q: A: B: C: D: ANS: EXP: lines, PLUS an
// optional block of Directions / puzzle information written BEFORE the
// questions it belongs to:
//
//   Directions (Q1-4): English line
//   निर्देश (प्र. 1-4): हिंदी लाइन        <- a line with Hindi letters = Hindi
//   * bullet line English || bullet line Hindi
//   Q: ... (the questions of this group)
//   ------------------------------      <- ends the group (3+ dashes)
//
// Everything between "Directions" (or the start / a ---- line) and the next
// "Q:" is the shared passage. All following questions get it, until the
// next ---- line or the next "Directions" line.

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

/// Reasoning sample (Directions + puzzle information + questions).
const String kReasoningBulkTemplate = r'''Directions (Q1-2): Study the information and answer the questions.
निर्देश (प्र. 1-2): जानकारी का अध्ययन करें और प्रश्नों के उत्तर दें।
Five boxes A, B, C, D and E are kept one above another. Box A is at the top. Box C is immediately below Box A.
पाँच बॉक्स A, B, C, D और E एक के ऊपर एक रखे गए हैं। बॉक्स A सबसे ऊपर है। बॉक्स C, बॉक्स A के ठीक नीचे है।
* Box E is at the bottom. || * बॉक्स E सबसे नीचे है।
Q: Which box is kept at the top? || सबसे ऊपर कौन सा बॉक्स रखा गया है?
A: Box A || बॉक्स A
B: Box B || बॉक्स B
C: Box C || बॉक्स C
D: Box E || बॉक्स E
ANS: A
EXP: Box A is at the top. || बॉक्स A सबसे ऊपर है।
Q: Which box is immediately below Box A? || बॉक्स A के ठीक नीचे कौन सा बॉक्स है?
A: Box B || बॉक्स B
B: Box C || बॉक्स C
C: Box D || बॉक्स D
D: Box E || बॉक्स E
ANS: B
EXP: Box C is immediately below Box A. || बॉक्स C, बॉक्स A के ठीक नीचे है।
------------------------------
Directions (Q3-4): In the following questions, the symbols @ and # are used with the meanings given below.
निर्देश (प्र. 3-4): निम्नलिखित प्रश्नों में @ और # प्रतीकों का अर्थ नीचे दिया गया है।
* 'P @ Q' means 'P is not smaller than Q' || 'P @ Q' का अर्थ है 'P, Q से छोटा नहीं है'
* 'P # Q' means 'P is greater than Q' || 'P # Q' का अर्थ है 'P, Q से बड़ा है'
Q: Statements: M # N, N @ O | Conclusion: M # O || कथन: M # N, N @ O | निष्कर्ष: M # O
A: True || सत्य
B: False || असत्य
C: Cannot say || कह नहीं सकते
D: None of these || इनमें से कोई नहीं
ANS: A
EXP: M > N >= O, so M > O. || M > N >= O, इसलिए M > O।
------------------------------
Q: A question that has no directions (the line above clears the old ones). || बिना निर्देश वाला प्रश्न (ऊपर की लाइन पुराने निर्देश हटा देती है)।
A: One || एक
B: Two || दो
C: Three || तीन
D: Four || चार
ANS: C
EXP: Optional. || वैकल्पिक।
''';

/// True when the subject box says Reasoning (English or Hindi spelling).
bool isReasoningSubject(String subject) {
  final t = subject.trim().toLowerCase();
  if (t.isEmpty) return false;
  return t.contains('reasoning') ||
      t.contains('\u0930\u0940\u091c\u093c\u0928\u093f\u0902\u0917') || // रीज़निंग
      t.contains('\u0930\u0940\u091c\u0928\u093f\u0902\u0917') || // रीजनिंग
      t.contains('\u0924\u0930\u094d\u0915'); // तर्क
}

class McqParseResult {
  final List<MockQuestion> questions;
  final List<String> errors;
  final int blocksFound;
  const McqParseResult(this.questions, this.errors, this.blocksFound);

  /// True only when every question is valid AND the count is 10 to 100.
  bool get ok => errors.isEmpty;
}

class _Draft {
  String passage = '';
  String passageHi = '';
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
// Reasoning only.
final RegExp _sepRe = RegExp(r'^[\-\u2013\u2014_=*~]{3,}$');
final RegExp _dirRe = RegExp(r'^(?:directions?|\u0928\u093f\u0930\u094d\u0926\u0947\u0936)', caseSensitive: false); // Directions / निर्देश
final RegExp _devanagari = RegExp(r'[\u0900-\u097F]');
final RegExp _bulletRe = RegExp(r'^[*\u2022\-]\s+');

String _addLine(String old, String line) => old.isEmpty ? line : '$old\n$line';

String _cleanBullet(String s) {
  final t = s.trim();
  return _bulletRe.hasMatch(t) ? '\u2022 ${t.replaceFirst(_bulletRe, '')}' : t;
}

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

/// [reasoning] = true switches on the Reasoning format (Directions / puzzle
/// information before the questions). Every other subject uses the plain
/// format exactly as before.
McqParseResult parseBulkMcqs(String raw, {bool reasoning = false}) {
  final lines = raw.replaceAll('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final drafts = <_Draft>[];
  final errors = <String>[];
  _Draft? cur;
  var strayReported = false;

  // Reasoning: the passage being collected / the one the next questions get.
  var collecting = false;
  var passEn = '';
  var passHi = '';

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (reasoning) {
      // A ---- line ends the group: old directions are dropped.
      if (_sepRe.hasMatch(line)) {
        collecting = true;
        passEn = '';
        passHi = '';
        continue;
      }
      // A new "Directions" line starts a new passage (even without ----).
      if (!collecting && _dirRe.hasMatch(line)) {
        collecting = true;
        passEn = '';
        passHi = '';
      }
      if (collecting) {
        final q0 = _qRe.firstMatch(line);
        if (q0 == null) {
          // Passage line. "English || Hindi" is split; a line without ||
          // is Hindi if it has Hindi letters, otherwise English.
          if (line.contains('||')) {
            final parts = _split(line);
            // "* English || Hindi": the bullet on the English side is meant for both.
            final bullet = _bulletRe.hasMatch(parts[0]);
            if (parts[0].isNotEmpty) passEn = _addLine(passEn, _cleanBullet(parts[0]));
            if (parts[1].isNotEmpty) passHi = _addLine(passHi, _cleanBullet(bullet ? '* ${parts[1]}' : parts[1]));
          } else if (_devanagari.hasMatch(line)) {
            passHi = _addLine(passHi, _cleanBullet(line));
          } else {
            passEn = _addLine(passEn, _cleanBullet(line));
          }
          continue;
        }
        collecting = false; // the first question of this group
      }
    }

    final q = _qRe.firstMatch(line);
    if (q != null) {
      cur = _Draft();
      if (reasoning) {
        // Only Hindi directions written: show them for both languages.
        cur.passage = passEn.isNotEmpty ? passEn : passHi;
        cur.passageHi = passEn.isNotEmpty ? passHi : '';
      }
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
      passage: d.passage,
      // Hindi directions are used only when there are English ones too.
      passageHi: d.passage.isNotEmpty ? d.passageHi : '',
    ));
  }

  if (drafts.isEmpty) {
    errors.add('No question found. Every question must start with "Q:".');
  } else if (drafts.length < kBulkMinQuestions || drafts.length > kBulkMaxQuestions) {
    errors.insert(0, 'One paste must have $kBulkMinQuestions to $kBulkMaxQuestions questions (found ${drafts.length}).');
  }

  return McqParseResult(questions, errors, drafts.length);
}
