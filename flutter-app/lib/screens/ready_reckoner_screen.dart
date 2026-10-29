import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Ready Reckoner: gunit ke liye zaroori chart - squares, cubes, tables, roots,
/// fraction <-> percent aur prime numbers. Sab kuch phone par hi ban jaata hai
/// (hardcoded list nahi), Firestore ko 0 reads / 0 writes.
class ReadyReckonerScreen extends StatelessWidget {
  const ReadyReckonerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ready Reckoner / रेडी रेकनर'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppC.gold,
            labelColor: AppC.gold,
            unselectedLabelColor: AppC.text70,
            tabs: const [
              Tab(text: 'Squares'),
              Tab(text: 'Cubes'),
              Tab(text: 'Tables'),
              Tab(text: 'Roots'),
              Tab(text: 'Fraction %'),
              Tab(text: 'Primes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SquaresTab(),
            _CubesTab(),
            _TablesTab(),
            _RootsTab(),
            _FractionsTab(),
            _PrimesTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

Widget _cell(String left, String right, {double width = 150}) {
  return Container(
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.line)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: TextStyle(color: AppC.text70, fontSize: 13)),
        Text(right, style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    ),
  );
}

Widget _wrapPage(List<Widget> children, {String? note}) {
  return ListView(
    padding: const EdgeInsets.all(14),
    children: [
      Wrap(spacing: 8, runSpacing: 8, children: children),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(note, textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35)),
        ),
    ],
  );
}

String _num(double v, {int dec = 2}) {
  var s = v.toStringAsFixed(dec);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

// ---------------------------------------------------------------- tabs

class _SquaresTab extends StatelessWidget {
  const _SquaresTab();
  @override
  Widget build(BuildContext context) => _wrapPage(
        [for (var i = 1; i <= 50; i++) _cell('$i²', '${i * i}')],
        note: 'Squares 1 to 50 / वर्ग 1 से 50',
      );
}

class _CubesTab extends StatelessWidget {
  const _CubesTab();
  @override
  Widget build(BuildContext context) => _wrapPage(
        [for (var i = 1; i <= 30; i++) _cell('$i³', '${i * i * i}')],
        note: 'Cubes 1 to 30 / घन 1 से 30',
      );
}

class _TablesTab extends StatefulWidget {
  const _TablesTab();
  @override
  State<_TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends State<_TablesTab> {
  int _n = 13;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (var n = 2; n <= 30; n++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _n = n),
                    child: Container(
                      width: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _n == n ? AppC.gold : AppC.chip, borderRadius: BorderRadius.circular(20)),
                      child: Text('$n', style: TextStyle(color: _n == n ? AppC.onGold : AppC.text, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _wrapPage(
            [for (var i = 1; i <= 20; i++) _cell('$_n × $i', '${_n * i}')],
            note: 'Table of $_n / $_n का पहाड़ा',
          ),
        ),
      ],
    );
  }
}

class _RootsTab extends StatelessWidget {
  const _RootsTab();
  @override
  Widget build(BuildContext context) {
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(t, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
        );
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('Square roots / वर्गमूल', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 1; i <= 30; i++) _cell('√${i * i}', '$i', width: 110)]),
        head('Cube roots / घनमूल'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 1; i <= 15; i++) _cell('∛${i * i * i}', '$i', width: 110)]),
        head('Useful values / काम की वैल्यू'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _cell('√2', '1.414'),
          _cell('√3', '1.732'),
          _cell('√5', '2.236'),
          _cell('√6', '2.449'),
          _cell('√7', '2.646'),
          _cell('√8', '2.828'),
          _cell('√10', '3.162'),
          _cell('∛2', '1.260'),
          _cell('∛3', '1.442'),
          _cell('π', '3.1416'),
          _cell('22/7', '3.1428'),
          _cell('1/π', '0.3183'),
        ]),
      ],
    );
  }
}

class _FractionsTab extends StatelessWidget {
  const _FractionsTab();

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (var d = 2; d <= 20; d++) {
      final chips = <Widget>[];
      for (var n = 1; n < d; n++) {
        if (_gcd(n, d) != 1) continue;
        final whole = (100 * n) ~/ d;
        final rem = (100 * n) % d;
        // rem == 0: poora number; warna "14 2/7 %" jaisa mixed form
        final mixed = rem == 0 ? '$whole%' : '$whole ${rem ~/ _gcd(rem, d)}/${d ~/ _gcd(rem, d)} %';
        chips.add(Container(
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.line)),
          child: Column(
            children: [
              Text('$n/$d', style: TextStyle(color: AppC.text70, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text('${_num(100 * n / d)}%', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text(mixed, style: TextStyle(color: AppC.text54, fontSize: 10.5)),
            ],
          ),
        ));
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text('Denominator $d / हर $d', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13)),
      ));
      blocks.add(Wrap(spacing: 8, runSpacing: 8, children: chips));
    }
    blocks.add(Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text('Decimals rounded to 2 places; the small line is the exact mixed form.\nदशमलव 2 अंक तक; छोटी लाइन में सटीक मिश्रित रूप।',
          textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5, height: 1.35)),
    ));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 2, 14, 24), children: blocks);
  }
}

class _PrimesTab extends StatelessWidget {
  const _PrimesTab();

  @override
  Widget build(BuildContext context) {
    final primes = <int>[];
    for (var n = 2; n <= 200; n++) {
      var ok = true;
      for (var i = 2; i * i <= n; i++) {
        if (n % i == 0) {
          ok = false;
          break;
        }
      }
      if (ok) primes.add(n);
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in primes)
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppC.line)),
                child: Text('$p', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text('${primes.length} prime numbers up to 200 / 200 तक ${primes.length} अभाज्य संख्याएँ',
              textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11.5)),
        ),
      ],
    );
  }
}
