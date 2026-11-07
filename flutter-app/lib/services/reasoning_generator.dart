import 'dart:math';
import '../models/models.dart';

// =============================================================================
//  ReasoningGenerator - Reasoning ke sawal apne aap banata hai (bina internet,
//  bina Firestore). Har baar naye sawal, saath me English + Hindi explanation.
//  Sawal MockQuestion ki shakl me bante hain, isliye wahi QuizSessionScreen
//  (sahi/galat, explanation, ⭐ save, result) seedha chal jaata hai.
// =============================================================================

class ReasoningType {
  final String id;
  final String emoji;
  final String en;
  final String hi;
  final String hint;
  const ReasoningType(this.id, this.emoji, this.en, this.hi, this.hint);
}

const List<ReasoningType> kReasoningTypes = [
  ReasoningType('series', '🔢', 'Number Series', 'संख्या श्रृंखला', '3, 6, 12, 24, ?'),
  ReasoningType('letters', '🔤', 'Letter Series', 'अक्षर श्रृंखला', 'A, C, E, G, ?'),
  ReasoningType('coding', '🔐', 'Coding-Decoding', 'कोडिंग-डिकोडिंग', 'CAT → DBU, DOG → ?'),
  ReasoningType('calendar', '📆', 'Days & Calendar', 'दिन व कैलेंडर', 'Today Monday, after 45 days?'),
  ReasoningType('clock', '🕒', 'Clock Angle', 'घड़ी का कोण', '4:20 → angle?'),
  ReasoningType('rank', '🏅', 'Ranking & Order', 'रैंकिंग व क्रम', '12th from top, 25th from bottom'),
  ReasoningType('direction', '🧭', 'Direction Sense', 'दिशा ज्ञान', '3 km East, 4 km North → ?'),
];

class ReasoningGenerator {
  ReasoningGenerator._();

  static final Random _r = Random();

  /// [type] = kReasoningTypes ki koi id, ya 'mix' (sab types ka mel).
  static List<MockQuestion> generate(String type, int count) {
    final out = <MockQuestion>[];
    final seen = <String>{};
    var guard = 0;
    while (out.length < count && guard < count * 40) {
      guard++;
      final t = type == 'mix' ? kReasoningTypes[_r.nextInt(kReasoningTypes.length)].id : type;
      MockQuestion? q;
      try {
        q = _make(t);
      } catch (_) {
        q = null; // koi gadbad to naya sawal try hoga
      }
      if (q == null) continue;
      if (!seen.add(q.text)) continue;
      out.add(q);
    }
    return out;
  }

  static MockQuestion _make(String t) {
    switch (t) {
      case 'series':
        return _series();
      case 'letters':
        return _letters();
      case 'coding':
        return _coding();
      case 'calendar':
        return _calendar();
      case 'clock':
        return _clock();
      case 'rank':
        return _rank();
      case 'direction':
        return _direction();
    }
    throw ArgumentError('unknown type $t');
  }

  // ------------------------------------------------------------- helpers

  /// choices[0] = sahi jawab. Options ko shuffle karke MockQuestion banata hai.
  static MockQuestion _mk({
    required String text,
    required String textHi,
    required List<String> choices,
    List<String>? choicesHi,
    required String exp,
    required String expHi,
  }) {
    if (choices.length != 4 || choices.toSet().length != 4) {
      throw StateError('need 4 different options');
    }
    final order = <int>[0, 1, 2, 3]..shuffle(_r);
    final opts = <String>[for (final i in order) choices[i]];
    final optsHi = choicesHi == null ? <String>[] : <String>[for (final i in order) choicesHi[i]];
    return MockQuestion(
      text: text,
      options: opts,
      correctIndex: order.indexOf(0),
      textHi: textHi,
      optionsHi: optsHi,
      explanation: exp,
      explanationHi: expHi,
    );
  }

  /// 3 galat numbers: pehle [priority] (jaise common galti), phir [fillers].
  static List<int> _wrongInts(int correct, List<int> priority, List<int> fillers) {
    final pool = <int>[...priority, ...(List<int>.from(fillers)..shuffle(_r))];
    final w = <int>[];
    for (final v in pool) {
      if (v == correct || w.contains(v)) continue;
      if (correct > 0 && v <= 0) continue;
      w.add(v);
      if (w.length == 3) break;
    }
    return w;
  }

  static List<int> _nearby(int ans, int unit) {
    final u = unit < 1 ? 1 : unit;
    final offs = <int>[1, -1, 2, -2, 3, -3, 4, -4, 5, -5];
    return <int>[for (final o in offs) ans + o * u];
  }

  static String _ord(int n) {
    final m100 = n % 100;
    if (m100 >= 11 && m100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
    }
    return '${n}th';
  }

  // -------------------------------------------------------- number series

  static MockQuestion _series() {
    final k = _r.nextInt(7);
    var s = <int>[];
    var ruleEn = '';
    var ruleHi = '';
    switch (k) {
      case 0:
        {
          final a = 2 + _r.nextInt(30);
          final d = 2 + _r.nextInt(9);
          s = <int>[for (var i = 0; i < 6; i++) a + d * i];
          ruleEn = 'Each term is $d more than the one before it (+$d).';
          ruleHi = 'हर पद पिछले पद से $d अधिक है (+$d)।';
          break;
        }
      case 1:
        {
          final a = 1 + _r.nextInt(5);
          final m = 2 + _r.nextInt(2);
          var v = a;
          for (var i = 0; i < 6; i++) {
            s.add(v);
            v *= m;
          }
          ruleEn = 'Each term is multiplied by $m (×$m).';
          ruleHi = 'हर पद को $m से गुणा किया जाता है (×$m)।';
          break;
        }
      case 2:
        {
          final n = 2 + _r.nextInt(8);
          s = <int>[for (var i = 0; i < 6; i++) (n + i) * (n + i)];
          ruleEn = 'These are squares of consecutive numbers: $n², ${n + 1}², ${n + 2}² ...';
          ruleHi = 'ये क्रमागत संख्याओं के वर्ग हैं: $n², ${n + 1}², ${n + 2}² ...';
          break;
        }
      case 3:
        {
          final n = 1 + _r.nextInt(5);
          s = <int>[for (var i = 0; i < 6; i++) (n + i) * (n + i) * (n + i)];
          ruleEn = 'These are cubes of consecutive numbers: $n³, ${n + 1}³, ${n + 2}³ ...';
          ruleHi = 'ये क्रमागत संख्याओं के घन हैं: $n³, ${n + 1}³, ${n + 2}³ ...';
          break;
        }
      case 4:
        {
          final a = 1 + _r.nextInt(20);
          final d = 1 + _r.nextInt(4);
          var v = a;
          for (var i = 0; i < 6; i++) {
            s.add(v);
            v += d + i;
          }
          ruleEn = 'The differences grow by 1 each time: +$d, +${d + 1}, +${d + 2}, +${d + 3}, +${d + 4}.';
          ruleHi = 'अंतर हर बार 1 बढ़ता है: +$d, +${d + 1}, +${d + 2}, +${d + 3}, +${d + 4}।';
          break;
        }
      case 5:
        {
          final a = 1 + _r.nextInt(4);
          final m = 2 + _r.nextInt(2);
          final c = 1 + _r.nextInt(3);
          var v = a;
          for (var i = 0; i < 6; i++) {
            s.add(v);
            v = v * m + c;
          }
          ruleEn = 'Multiply the previous term by $m, then add $c (×$m + $c).';
          ruleHi = 'पिछले पद को $m से गुणा करके $c जोड़ें (×$m + $c)।';
          break;
        }
      default:
        {
          final n = 2 + _r.nextInt(7);
          final c = 1 + _r.nextInt(5);
          final plus = _r.nextBool();
          s = <int>[for (var i = 0; i < 6; i++) (n + i) * (n + i) + (plus ? c : -c)];
          ruleEn = 'Square of each consecutive number ${plus ? 'plus' : 'minus'} $c: $n² ${plus ? '+' : '−'} $c, ${n + 1}² ${plus ? '+' : '−'} $c ...';
          ruleHi = 'क्रमागत संख्याओं के वर्ग ${plus ? 'में $c जोड़ें' : 'में से $c घटाएँ'}: $n² ${plus ? '+' : '−'} $c, ${n + 1}² ${plus ? '+' : '−'} $c ...';
          break;
        }
    }
    final ans = s[5];
    final shown = s.sublist(0, 5).join(', ');
    final unit = max(1, ans.abs() ~/ 12);
    final wrong = _wrongInts(ans, const <int>[], _nearby(ans, unit));
    return _mk(
      text: 'Find the next number in the series:\n$shown, ?',
      textHi: 'श्रृंखला की अगली संख्या ज्ञात कीजिए:\n$shown, ?',
      choices: <String>[ans.toString(), ...wrong.map((e) => e.toString())],
      exp: '$ruleEn\nSo the next number is $ans.',
      expHi: '$ruleHi\nइसलिए अगली संख्या $ans है।',
    );
  }

  // -------------------------------------------------------- letter series

  static MockQuestion _letters() {
    final step = 1 + _r.nextInt(4); // 1..4
    final start = _r.nextInt(26 - 5 * step); // 6va akshar 25 se bahar na jaye
    final desc = _r.nextBool();
    int pos(int i) {
      final p = start + step * i;
      return desc ? 25 - p : p;
    }

    String ch(int p) => String.fromCharCode(65 + p);
    final shown = <String>[for (var i = 0; i < 5; i++) ch(pos(i))].join(', ');
    final ansPos = pos(5);
    final cand = <int>[ansPos + 1, ansPos - 1, ansPos + 2, ansPos - 2, ansPos + 3, ansPos - 3]..shuffle(_r);
    final wrong = <String>[];
    for (final p in cand) {
      if (p < 0 || p > 25 || p == ansPos) continue;
      wrong.add(ch(p));
      if (wrong.length == 3) break;
    }
    final dirEn = desc ? 'backward' : 'forward';
    final dirHi = desc ? 'पीछे' : 'आगे';
    return _mk(
      text: 'Find the next letter in the series:\n$shown, ?',
      textHi: 'श्रृंखला का अगला अक्षर ज्ञात कीजिए:\n$shown, ?',
      choices: <String>[ch(ansPos), ...wrong],
      exp: 'Each letter moves $step place${step > 1 ? 's' : ''} $dirEn in the alphabet. So the next letter is ${ch(ansPos)}.',
      expHi: 'हर अक्षर वर्णमाला में $step स्थान $dirHi खिसकता है। इसलिए अगला अक्षर ${ch(ansPos)} है।',
    );
  }

  // ------------------------------------------------------ coding-decoding

  static const List<String> _words = [
    'PEN', 'BAG', 'CAT', 'DOG', 'SUN', 'MAP', 'FAN', 'BOX', 'CUP', 'HAT', 'KEY', 'ARM', 'BUS', 'JAR', 'TEA', 'EGG', 'RAT', 'LION'
  ];

  static String _shift(String w, int s) {
    final b = StringBuffer();
    for (final c in w.codeUnits) {
      b.writeCharCode(65 + ((c - 65 + s) % 26 + 26) % 26);
    }
    return b.toString();
  }

  static MockQuestion _coding() {
    var s = 1 + _r.nextInt(4);
    if (_r.nextBool()) s = -s;
    final w1 = _words[_r.nextInt(_words.length)];
    var w2 = _words[_r.nextInt(_words.length)];
    var tries = 0;
    while (w2 == w1 && tries < 20) {
      w2 = _words[_r.nextInt(_words.length)];
      tries++;
    }
    if (w2 == w1) throw StateError('same word');
    final c1 = _shift(w1, s);
    final correct = _shift(w2, s);
    final others = <int>[-4, -3, -2, -1, 1, 2, 3, 4]..shuffle(_r);
    final wrong = <String>[];
    for (final o in others) {
      if (o == s) continue;
      final code = _shift(w2, o);
      if (code == correct || wrong.contains(code)) continue;
      wrong.add(code);
      if (wrong.length == 3) break;
    }
    final n = s.abs();
    final dirEn = s > 0 ? 'forward' : 'backward';
    final dirHi = s > 0 ? 'आगे' : 'पीछे';
    return _mk(
      text: 'If $w1 is coded as $c1, how will $w2 be coded in the same way?',
      textHi: 'यदि $w1 को $c1 लिखा जाता है, तो उसी तरह $w2 को कैसे लिखा जाएगा?',
      choices: <String>[correct, ...wrong],
      exp: 'Every letter is shifted $n place${n > 1 ? 's' : ''} $dirEn ($w1 → $c1).\nSo $w2 → $correct.',
      expHi: 'हर अक्षर $n स्थान $dirHi खिसकाया गया है ($w1 → $c1)।\nइसलिए $w2 → $correct।',
    );
  }

  // ----------------------------------------------------------- calendar

  static const List<String> _dEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const List<String> _dHi = ['सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार'];

  static MockQuestion _calendar() {
    final d = _r.nextInt(7);
    late int ansIdx;
    late String text;
    late String textHi;
    late String exp;
    late String expHi;
    if (_r.nextBool()) {
      final n = 10 + _r.nextInt(190);
      final after = _r.nextBool();
      final rem = n % 7;
      ansIdx = after ? (d + rem) % 7 : ((d - rem) % 7 + 7) % 7;
      text = 'Today is ${_dEn[d]}. What day of the week ${after ? 'will it be after' : 'was it'} $n days${after ? '' : ' ago'}?';
      textHi = 'आज ${_dHi[d]} है। $n दिन ${after ? 'बाद' : 'पहले'} सप्ताह का कौन-सा दिन ${after ? 'होगा' : 'था'}?';
      exp = '$n ÷ 7 leaves remainder $rem (odd days).\n${_dEn[d]} ${after ? '+' : '−'} $rem day${rem == 1 ? '' : 's'} = ${_dEn[ansIdx]}.';
      expHi = '$n ÷ 7 का शेष $rem (विषम दिन) है।\n${_dHi[d]} ${after ? '+' : '−'} $rem दिन = ${_dHi[ansIdx]}।';
    } else {
      final a = 1 + _r.nextInt(14);
      final b = a + 7 + _r.nextInt(30 - a - 7 + 1 > 0 ? 30 - a - 7 + 1 : 1);
      final n = b - a;
      final rem = n % 7;
      ansIdx = (d + rem) % 7;
      text = 'If the ${_ord(a)} of a month is a ${_dEn[d]}, which day will the ${_ord(b)} of that month be?';
      textHi = 'यदि किसी माह की $a तारीख़ को ${_dHi[d]} है, तो उसी माह की $b तारीख़ को कौन-सा दिन होगा?';
      exp = 'Difference = $b − $a = $n days. $n ÷ 7 leaves remainder $rem.\n${_dEn[d]} + $rem day${rem == 1 ? '' : 's'} = ${_dEn[ansIdx]}.';
      expHi = 'अंतर = $b − $a = $n दिन। $n ÷ 7 का शेष $rem है।\n${_dHi[d]} + $rem दिन = ${_dHi[ansIdx]}।';
    }
    final others = <int>[for (var i = 0; i < 7; i++) if (i != ansIdx) i]..shuffle(_r);
    final pick = others.take(3).toList();
    return _mk(
      text: text,
      textHi: textHi,
      choices: <String>[_dEn[ansIdx], for (final i in pick) _dEn[i]],
      choicesHi: <String>[_dHi[ansIdx], for (final i in pick) _dHi[i]],
      exp: exp,
      expHi: expHi,
    );
  }

  // -------------------------------------------------------------- clock

  /// twice = aadha-degree ki ginti (taaki .5 degree bhi sahi aaye).
  static String _h(int twice) => twice.isEven ? '${twice ~/ 2}' : '${twice ~/ 2}.5';

  static MockQuestion _clock() {
    final h = 1 + _r.nextInt(12);
    final m = _r.nextInt(12) * 5; // 0, 5, 10 ... 55
    final diff = (60 * h - 11 * m).abs(); // aadhe degree me |30H - 5.5M|
    final ang2 = diff > 360 ? 720 - diff : diff;
    final cand = <int>[ang2 + 10, ang2 - 10, ang2 + 20, ang2 - 20, ang2 + 30, ang2 - 30, ang2 + 40, ang2 - 40]..shuffle(_r);
    final wrong = <String>[];
    for (final v in cand) {
      if (v < 0 || v > 360 || v == ang2) continue;
      wrong.add('${_h(v)}°');
      if (wrong.length == 3) break;
    }
    final time = '$h:${m.toString().padLeft(2, '0')}';
    final over = diff > 360
        ? '\nThis is more than 180°, so take 360° − ${_h(diff)}° = ${_h(ang2)}°.'
        : '';
    final overHi = diff > 360
        ? '\nयह 180° से अधिक है, इसलिए 360° − ${_h(diff)}° = ${_h(ang2)}°।'
        : '';
    return _mk(
      text: 'What is the angle between the hour hand and the minute hand of a clock at $time?',
      textHi: 'घड़ी में $time बजे घंटे और मिनट की सुइयों के बीच कितना कोण बनेगा?',
      choices: <String>['${_h(ang2)}°', ...wrong],
      exp: 'Angle = |30×H − 5.5×M| = |30×$h − 5.5×$m| = |${_h(60 * h)} − ${_h(11 * m)}| = ${_h(diff)}°.$over\nAnswer: ${_h(ang2)}°.',
      expHi: 'कोण = |30×H − 5.5×M| = |30×$h − 5.5×$m| = |${_h(60 * h)} − ${_h(11 * m)}| = ${_h(diff)}°।$overHi\nउत्तर: ${_h(ang2)}°।',
    );
  }

  // --------------------------------------------------------------- rank

  static const List<String> _names = ['Rahul', 'Amit', 'Neha', 'Priya', 'Sonu', 'Ravi', 'Anita', 'Mohit', 'Pooja', 'Kiran'];
  static const List<String> _namesHi = ['राहुल', 'अमित', 'नेहा', 'प्रिया', 'सोनू', 'रवि', 'अनीता', 'मोहित', 'पूजा', 'किरण'];

  static MockQuestion _rank() {
    final ni = _r.nextInt(_names.length);
    final nm = _names[ni];
    final nmHi = _namesHi[ni];
    if (_r.nextBool()) {
      final a = 5 + _r.nextInt(30);
      final b = 5 + _r.nextInt(30);
      final total = a + b - 1;
      final wrong = _wrongInts(total, <int>[a + b], <int>[total + 1, total - 1, total + 2, total - 2, total + 3]);
      return _mk(
        text: '$nm ranks ${_ord(a)} from the top and ${_ord(b)} from the bottom in a class. How many students are there in the class?',
        textHi: 'एक कक्षा में $nmHi का स्थान ऊपर से $a वाँ और नीचे से $b वाँ है। कक्षा में कुल कितने विद्यार्थी हैं?',
        choices: <String>[total.toString(), ...wrong.map((e) => e.toString())],
        exp: 'Total = (rank from top) + (rank from bottom) − 1 = $a + $b − 1 = $total.',
        expHi: 'कुल = (ऊपर से स्थान) + (नीचे से स्थान) − 1 = $a + $b − 1 = $total।',
      );
    }
    final n = 20 + _r.nextInt(41);
    final l = 5 + _r.nextInt(n - 9);
    final ans = n - l + 1;
    final wrong = _wrongInts(ans, <int>[n - l], <int>[ans + 1, ans - 1, ans + 2, ans - 2, ans + 3]);
    return _mk(
      text: 'There are $n students standing in a row. If $nm is ${_ord(l)} from the left end, what is $nm\'s position from the right end?',
      textHi: 'एक पंक्ति में $n विद्यार्थी खड़े हैं। यदि $nmHi बाएँ छोर से $l वाँ है, तो दाएँ छोर से उसका स्थान क्या होगा?',
      choices: <String>[ans.toString(), ...wrong.map((e) => e.toString())],
      exp: 'Position from right = Total − Position from left + 1 = $n − $l + 1 = $ans.',
      expHi: 'दाएँ से स्थान = कुल − बाएँ से स्थान + 1 = $n − $l + 1 = $ans।',
    );
  }

  // ---------------------------------------------------------- direction

  static const List<List<int>> _triples = [
    [3, 4, 5], [5, 12, 13], [8, 15, 17], [6, 8, 10], [9, 12, 15], [7, 24, 25], [12, 16, 20], [15, 20, 25], [10, 24, 26], [20, 21, 29]
  ];

  static MockQuestion _direction() {
    final t = _triples[_r.nextInt(_triples.length)];
    var a = t[0];
    var b = t[1];
    final c = t[2];
    if (_r.nextBool()) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    final firstEn = _r.nextBool() ? 'East' : 'West';
    final secondEn = _r.nextBool() ? 'North' : 'South';
    final firstHi = firstEn == 'East' ? 'पूर्व' : 'पश्चिम';
    final secondHi = secondEn == 'North' ? 'उत्तर' : 'दक्षिण';
    final wrong = _wrongInts(c, <int>[a + b], <int>[c + 1, c - 1, c + 2, c - 2, c + 3]);
    return _mk(
      text: 'A man walks $a km towards $firstEn, then turns and walks $b km towards $secondEn. How far is he from the starting point?',
      textHi: 'एक आदमी $firstHi की ओर $a किमी चलता है, फिर मुड़कर $secondHi की ओर $b किमी चलता है। वह शुरुआती बिंदु से कितनी दूर है?',
      choices: <String>['$c km', ...wrong.map((e) => '$e km')],
      choicesHi: <String>['$c किमी', ...wrong.map((e) => '$e किमी')],
      exp: 'The two walks are at right angles, so use Pythagoras:\nDistance = √($a² + $b²) = √${a * a + b * b} = $c km.',
      expHi: 'दोनों रास्ते समकोण पर हैं, इसलिए पाइथागोरस से:\nदूरी = √($a² + $b²) = √${a * a + b * b} = $c किमी।',
    );
  }
}
