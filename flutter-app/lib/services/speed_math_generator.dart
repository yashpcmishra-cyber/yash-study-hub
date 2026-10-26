import 'dart:math';

// =============================================================================
//  Speed Maths Arena - sawal yahin PHONE par bante hain (random).
//  Koi Firestore read / write nahi, koi content upload nahi, kabhi khatam nahi.
//  Naya drill jodna ho: MathDrill me naam, kDrills me ek line, aur
//  SpeedMathGenerator.next() me ek case.
// =============================================================================

enum MathDrill { mix, squares, cubes, tables, roots, fractions, percent, quick, bodmas, series }

/// Menu me dikhne wali ek drill ki jaankari.
class DrillInfo {
  final MathDrill drill;
  final String emoji;
  final String en;
  final String hi;
  final String hint;
  const DrillInfo(this.drill, this.emoji, this.en, this.hi, this.hint);

  /// Phone me best score save karne ke liye pehchaan.
  String get id => drill.name;
}

const List<DrillInfo> kDrills = [
  DrillInfo(MathDrill.mix, '🎲', 'Mix All', 'सब मिलाकर', 'Every drill, random'),
  DrillInfo(MathDrill.squares, '²', 'Squares', 'वर्ग', '11² to 50²'),
  DrillInfo(MathDrill.cubes, '³', 'Cubes', 'घन', '2³ to 25³'),
  DrillInfo(MathDrill.tables, '✖️', 'Tables', 'पहाड़े', '11 to 30 tables'),
  DrillInfo(MathDrill.roots, '√', 'Roots', 'वर्गमूल / घनमूल', 'Square & cube roots'),
  DrillInfo(MathDrill.fractions, '➗', 'Fraction ↔ %', 'भिन्न ↔ प्रतिशत', '3/8 = 37.5%'),
  DrillInfo(MathDrill.percent, '％', 'Percentage', 'प्रतिशत', '35% of 240'),
  DrillInfo(MathDrill.quick, '⚡', 'Quick Calc', 'तेज़ गणना', 'Add, subtract, multiply'),
  DrillInfo(MathDrill.bodmas, '🧮', 'BODMAS', 'सरलीकरण', 'Simplify fast'),
  DrillInfo(MathDrill.series, '🔢', 'Number Series', 'संख्या श्रेणी', 'Find the next number'),
];

DrillInfo drillInfo(MathDrill d) => kDrills.firstWhere((e) => e.drill == d, orElse: () => kDrills.first);

/// Ek sawal: text + 4 options + sahi option ka number.
class SpeedQuestion {
  final String text;
  final List<String> options;
  final int correct;
  const SpeedQuestion(this.text, this.options, this.correct);
}

class SpeedMathGenerator {
  SpeedMathGenerator._();

  static SpeedQuestion next(MathDrill drill, Random r) {
    var d = drill;
    if (d == MathDrill.mix) {
      const pool = [
        MathDrill.squares,
        MathDrill.cubes,
        MathDrill.tables,
        MathDrill.roots,
        MathDrill.fractions,
        MathDrill.percent,
        MathDrill.quick,
        MathDrill.bodmas,
        MathDrill.series,
      ];
      d = pool[r.nextInt(pool.length)];
    }
    switch (d) {
      case MathDrill.squares:
        return _squares(r);
      case MathDrill.cubes:
        return _cubes(r);
      case MathDrill.tables:
        return _tables(r);
      case MathDrill.roots:
        return _roots(r);
      case MathDrill.fractions:
        return _fractions(r);
      case MathDrill.percent:
        return _percent(r);
      case MathDrill.quick:
        return _quick(r);
      case MathDrill.bodmas:
        return _bodmas(r);
      case MathDrill.series:
        return _series(r);
      case MathDrill.mix:
        return _tables(r); // yahan kabhi nahi aata (upar pool se chuna ja chuka)
    }
  }

  // ------------------------------------------------------------- helpers

  /// Number wale jawab ke liye 4 options banata hai (1 sahi + 3 galat, sab alag).
  /// [near] = "lubhaane" galat jawab (jaise (n-1)², (n+1)²).
  static SpeedQuestion _numeric(String text, int ans, Random r, {List<int> near = const <int>[]}) {
    final set = <int>{ans};
    final tricky = List<int>.from(near)..shuffle(r);
    for (final v in tricky) {
      if (set.length >= 4) break;
      if (v < 0 && ans >= 0) continue;
      set.add(v);
    }
    final a = ans.abs();
    final scale = a < 20 ? 1 : (a < 200 ? 2 : (a < 2000 ? 10 : 100));
    var guard = 0;
    while (set.length < 4 && guard < 80) {
      guard++;
      final k = r.nextInt(8) + 1;
      final v = ans + (r.nextBool() ? k : -k) * scale;
      if (v < 0 && ans >= 0) continue;
      set.add(v);
    }
    var f = 1;
    while (set.length < 4) {
      set.add(ans + f);
      f++;
    }
    final list = set.toList()..shuffle(r);
    return SpeedQuestion(text, list.map((e) => e.toString()).toList(), list.indexOf(ans));
  }

  static SpeedQuestion _fromStrings(String text, String right, List<String> wrongPool, Random r) {
    final wrong = wrongPool.where((e) => e != right).toSet().toList()..shuffle(r);
    final opts = <String>[right, ...wrong.take(3)]..shuffle(r);
    return SpeedQuestion(text, opts, opts.indexOf(right));
  }

  // -------------------------------------------------------------- drills

  static SpeedQuestion _squares(Random r) {
    final n = 11 + r.nextInt(40); // 11..50
    return _numeric('$n²', n * n, r, near: [(n - 1) * (n - 1), (n + 1) * (n + 1), n * n + 10, n * n - 10]);
  }

  static SpeedQuestion _cubes(Random r) {
    final n = 2 + r.nextInt(24); // 2..25
    return _numeric('$n³', n * n * n, r, near: [(n - 1) * (n - 1) * (n - 1), (n + 1) * (n + 1) * (n + 1), n * n * 3]);
  }

  static SpeedQuestion _tables(Random r) {
    final a = 11 + r.nextInt(20); // 11..30
    final b = 2 + r.nextInt(18); // 2..19
    return _numeric('$a × $b', a * b, r, near: [a * (b - 1), a * (b + 1), (a + 1) * b, (a - 1) * b]);
  }

  static SpeedQuestion _roots(Random r) {
    if (r.nextBool()) {
      final n = 11 + r.nextInt(40); // 11..50
      return _numeric('√${n * n}', n, r, near: [n - 1, n + 1, n + 2, n - 2, n + 10]);
    }
    final n = 2 + r.nextInt(24); // 2..25
    return _numeric('∛${n * n * n}', n, r, near: [n - 1, n + 1, n + 2, n - 2]);
  }

  // [fraction, percent] - bhartiya kitabon me aam taur par yahi likha hota hai.
  static const List<List<String>> _fr = [
    ['1/2', '50%'],
    ['1/3', '33.33%'],
    ['2/3', '66.66%'],
    ['1/4', '25%'],
    ['3/4', '75%'],
    ['1/5', '20%'],
    ['2/5', '40%'],
    ['3/5', '60%'],
    ['4/5', '80%'],
    ['1/6', '16.66%'],
    ['5/6', '83.33%'],
    ['1/7', '14.28%'],
    ['1/8', '12.5%'],
    ['3/8', '37.5%'],
    ['5/8', '62.5%'],
    ['7/8', '87.5%'],
    ['1/9', '11.11%'],
    ['1/10', '10%'],
    ['1/11', '9.09%'],
    ['1/12', '8.33%'],
    ['1/15', '6.66%'],
    ['1/16', '6.25%'],
    ['1/20', '5%'],
  ];

  static SpeedQuestion _fractions(Random r) {
    final row = _fr[r.nextInt(_fr.length)];
    if (r.nextBool()) {
      return _fromStrings('${row[0]} = ?', row[1], _fr.map((e) => e[1]).toList(), r);
    }
    return _fromStrings('${row[1]} = ?', row[0], _fr.map((e) => e[0]).toList(), r);
  }

  static SpeedQuestion _percent(Random r) {
    const ps = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 65, 70, 75, 80, 90, 120, 150];
    final p = ps[r.nextInt(ps.length)];
    final n = 20 * (2 + r.nextInt(59)); // 40..1200 (p*n/100 hamesha poora number)
    final ans = p * n ~/ 100;
    return _numeric('$p% of $n', ans, r, near: [ans + p, ans - p, ans + 10, ans - 10, ans * 2]);
  }

  static SpeedQuestion _quick(Random r) {
    switch (r.nextInt(4)) {
      case 0: {
        final a = 12 + r.nextInt(88); // 12..99
        final b = 2 + r.nextInt(8); // 2..9
        return _numeric('$a × $b', a * b, r, near: [a * b + 10, a * b - 10, a * (b + 1), a * (b - 1)]);
      }
      case 1: {
        final a = 100 + r.nextInt(900);
        final b = 100 + r.nextInt(900);
        return _numeric('$a + $b', a + b, r, near: [a + b + 10, a + b - 10, a + b + 100, a + b - 100]);
      }
      case 2: {
        final a = 500 + r.nextInt(500); // 500..999
        final b = 100 + r.nextInt(400); // 100..499
        return _numeric('$a − $b', a - b, r, near: [a - b + 10, a - b - 10, a - b + 100, a - b - 100]);
      }
      default: {
        final a = 11 + r.nextInt(25); // 11..35
        final b = 11 + r.nextInt(25);
        return _numeric('$a × $b', a * b, r, near: [a * b + 10, a * b - 10, a * (b + 1), (a - 1) * b]);
      }
    }
  }

  static SpeedQuestion _bodmas(Random r) {
    switch (r.nextInt(4)) {
      case 0: {
        final a = 10 + r.nextInt(51);
        final b = 2 + r.nextInt(11);
        final c = 2 + r.nextInt(8);
        final ans = a + b * c;
        return _numeric('$a + $b × $c', ans, r, near: [(a + b) * c, ans + b, ans - c]);
      }
      case 1: {
        final a = 3 + r.nextInt(10);
        final b = 3 + r.nextInt(10);
        final d = 2 + r.nextInt(8);
        final k = 2 + r.nextInt(8);
        final c = d * k;
        final ans = a * b - k;
        return _numeric('$a × $b − $c ÷ $d', ans, r, near: [a * b - c, ans + 2, ans - 2]);
      }
      case 2: {
        final a = 5 + r.nextInt(36);
        final b = 5 + r.nextInt(36);
        final c = 2 + r.nextInt(8);
        final ans = (a + b) * c;
        return _numeric('($a + $b) × $c', ans, r, near: [a + b * c, ans + c, ans - c]);
      }
      default: {
        var a = 4 + r.nextInt(12);
        var b = 4 + r.nextInt(12);
        var c = 2 + r.nextInt(8);
        var d = 2 + r.nextInt(8);
        if (a * b < c * d) {
          final ta = a;
          final tb = b;
          a = c;
          b = d;
          c = ta;
          d = tb;
        }
        final ans = a * b - c * d;
        return _numeric('$a × $b − $c × $d', ans, r, near: [ans + 10, ans - 10, a * b + c * d]);
      }
    }
  }

  static SpeedQuestion _series(Random r) {
    switch (r.nextInt(4)) {
      case 0: { // barabar antar
        final s = 2 + r.nextInt(30);
        final d = 2 + r.nextInt(11);
        final terms = List<int>.generate(5, (i) => s + i * d);
        final ans = s + 5 * d;
        return _numeric('${terms.join(', ')}, ?', ans, r, near: [ans + d, ans - d, ans + 2, ans - 2]);
      }
      case 1: { // guna (x2 ya x3)
        final s = 2 + r.nextInt(5);
        final q = 2 + r.nextInt(2);
        var cur = s;
        final terms = <int>[];
        for (var i = 0; i < 4; i++) {
          terms.add(cur);
          cur *= q;
        }
        return _numeric('${terms.join(', ')}, ?', cur, r, near: [cur + q, cur - q, cur + 2 * q]);
      }
      case 2: { // vargon ki shrinkhla
        final n = 2 + r.nextInt(12);
        final terms = List<int>.generate(4, (i) => (n + i) * (n + i));
        final ans = (n + 4) * (n + 4);
        return _numeric('${terms.join(', ')}, ?', ans, r, near: [ans + 2, ans - (n + 4), (n + 5) * (n + 5)]);
      }
      default: { // badhta hua antar
        final s = 1 + r.nextInt(20);
        final d1 = 1 + r.nextInt(4);
        final c = 1 + r.nextInt(3);
        final terms = <int>[s];
        for (var i = 0; i < 5; i++) {
          terms.add(terms.last + d1 + i * c);
        }
        final shown = terms.take(5).toList();
        final ans = terms[5];
        return _numeric('${shown.join(', ')}, ?', ans, r, near: [ans + c, ans - c, ans + 2, ans - 2]);
      }
    }
  }
}
