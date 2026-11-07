import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'age_calculator_screen.dart';

// =============================================================================
//  Quick Calculators - exam ke kaam aane wale chhote calculators (Percentage,
//  Profit & Loss, Discount, SI / CI, EMI, Average, Ratio, Time & Work,
//  Speed). Har calculator formula bhi dikhata hai. Pura offline - kuch save
//  nahi hota, Firestore ko 0 reads / 0 writes.
//  Naya calculator jodne ke liye bas `_groups` me ek _Calc badhao.
// =============================================================================

/// Ek input box. [def] diya ho to box khali chhodne par wahi value li jaati hai.
class _F {
  final String key;
  final String label;
  final String hint;
  final String? def;
  final bool list; // "2, 3, 5" jaisi kai values
  const _F(this.key, this.label, {this.hint = '', this.def, this.list = false});
}

class _In {
  final Map<String, List<double>> m;
  const _In(this.m);
  double n(String k) => m[k]!.first;
  List<double> l(String k) => m[k]!;
}

class _Calc {
  final String emoji;
  final String title;
  final String titleHi;
  final String formula;
  final List<_F> fields;

  /// null = values galat (jaise 0 se bhaag). Warna [label, value] ki list.
  final List<List<String>>? Function(_In i) compute;
  const _Calc(this.emoji, this.title, this.titleHi, this.formula, this.fields, this.compute);
}

class _Group {
  final String title;
  final List<_Calc> calcs;
  const _Group(this.title, this.calcs);
}

/// 12.0 -> "12", 12.345 -> "12.35", 1234567.5 -> "1234567.5"
String _fmt(double v) {
  if (v.isNaN || v.isInfinite) return '--';
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toStringAsFixed(0);
  var s = r.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

final List<_Group> _groups = [
  _Group('Percentage / प्रतिशत', [
    _Calc(
      '％',
      'X% of a number',
      'किसी संख्या का X%',
      'Answer = X × Number ÷ 100\nउत्तर = X × संख्या ÷ 100',
      const [_F('p', 'Percentage (X %)', hint: 'e.g. 15'), _F('b', 'Number', hint: 'e.g. 640')],
      (i) => [
        ['Answer / उत्तर', _fmt(i.n('p') * i.n('b') / 100)],
      ],
    ),
    _Calc(
      '🔢',
      'What % is A of B?',
      'A, B का कितने % है?',
      'Percentage = (A ÷ B) × 100\nप्रतिशत = (A ÷ B) × 100',
      const [_F('a', 'A (part)', hint: 'e.g. 45'), _F('b', 'B (total)', hint: 'e.g. 180')],
      (i) => i.n('b') == 0
          ? null
          : [
              ['Percentage / प्रतिशत', '${_fmt(i.n('a') / i.n('b') * 100)}%'],
            ],
    ),
    _Calc(
      '📈',
      '% Increase / Decrease',
      '% वृद्धि / कमी',
      'Change % = (New − Old) ÷ Old × 100\nबदलाव % = (नया − पुराना) ÷ पुराना × 100',
      const [_F('o', 'Old value', hint: 'e.g. 800'), _F('n', 'New value', hint: 'e.g. 920')],
      (i) {
        if (i.n('o') == 0) return null;
        final d = i.n('n') - i.n('o');
        final pct = d / i.n('o') * 100;
        return [
          ['Change / बदलाव', _fmt(d)],
          [pct >= 0 ? 'Increase % / वृद्धि %' : 'Decrease % / कमी %', '${_fmt(pct.abs())}%'],
        ];
      },
    ),
  ]),
  _Group('Profit, Loss & Discount / लाभ, हानि और छूट', [
    _Calc(
      '💹',
      'Profit & Loss %',
      'लाभ और हानि %',
      'Profit % = (SP − CP) ÷ CP × 100\nलाभ % = (विक्रय − क्रय) ÷ क्रय × 100',
      const [_F('cp', 'Cost Price (CP)', hint: 'e.g. 500'), _F('sp', 'Selling Price (SP)', hint: 'e.g. 575')],
      (i) {
        if (i.n('cp') <= 0) return null;
        final d = i.n('sp') - i.n('cp');
        final pct = d / i.n('cp') * 100;
        final profit = d >= 0;
        return [
          [profit ? 'Profit / लाभ' : 'Loss / हानि', _fmt(d.abs())],
          [profit ? 'Profit % / लाभ %' : 'Loss % / हानि %', '${_fmt(pct.abs())}%'],
        ];
      },
    ),
    _Calc(
      '🏷️',
      'Discount (single / successive)',
      'छूट (एकल / क्रमागत)',
      'Net discount % = d1 + d2 − (d1 × d2) ÷ 100\nSP = Marked Price × (100 − net discount) ÷ 100',
      const [
        _F('mp', 'Marked Price', hint: 'e.g. 2000'),
        _F('d1', 'Discount 1 (%)', hint: 'e.g. 20'),
        _F('d2', 'Discount 2 (%) - optional', hint: 'leave empty if none', def: '0'),
      ],
      (i) {
        final net = i.n('d1') + i.n('d2') - i.n('d1') * i.n('d2') / 100;
        final price = i.n('mp') * (100 - net) / 100;
        return [
          ['Selling Price / विक्रय मूल्य', _fmt(price)],
          ['You save / बचत', _fmt(i.n('mp') - price)],
          ['Net discount / कुल छूट', '${_fmt(net)}%'],
        ];
      },
    ),
  ]),
  _Group('Interest & EMI / ब्याज और EMI', [
    _Calc(
      '🏦',
      'Simple Interest',
      'साधारण ब्याज',
      'SI = P × R × T ÷ 100\nAmount = P + SI',
      const [
        _F('p', 'Principal (P)', hint: 'e.g. 10000'),
        _F('r', 'Rate per year (R %)', hint: 'e.g. 8'),
        _F('t', 'Time in years (T)', hint: 'e.g. 3'),
      ],
      (i) {
        final si = i.n('p') * i.n('r') * i.n('t') / 100;
        return [
          ['Simple Interest / साधारण ब्याज', _fmt(si)],
          ['Amount / मिश्रधन', _fmt(i.n('p') + si)],
        ];
      },
    ),
    _Calc(
      '📊',
      'Compound Interest',
      'चक्रवृद्धि ब्याज',
      'Amount = P × (1 + R ÷ (100 × n))^(n × T)\nCI = Amount − P      (n = times compounded per year)',
      const [
        _F('p', 'Principal (P)', hint: 'e.g. 10000'),
        _F('r', 'Rate per year (R %)', hint: 'e.g. 10'),
        _F('t', 'Time in years (T)', hint: 'e.g. 2'),
        _F('n', 'Compounded per year (n)', hint: '1 = yearly, 2 = half-yearly, 4 = quarterly', def: '1'),
      ],
      (i) {
        final n = i.n('n');
        if (n <= 0) return null;
        final amt = i.n('p') * math.pow(1 + i.n('r') / (100 * n), n * i.n('t'));
        final si = i.n('p') * i.n('r') * i.n('t') / 100;
        return [
          ['Compound Interest / चक्रवृद्धि ब्याज', _fmt(amt - i.n('p'))],
          ['Amount / मिश्रधन', _fmt(amt)],
          ['CI − SI difference / अंतर', _fmt(amt - i.n('p') - si)],
        ];
      },
    ),
    _Calc(
      '🏠',
      'Loan EMI',
      'लोन EMI',
      'EMI = P × r × (1+r)^n ÷ ((1+r)^n − 1)\nr = yearly rate ÷ 12 ÷ 100,  n = months',
      const [
        _F('p', 'Loan amount (P)', hint: 'e.g. 500000'),
        _F('r', 'Interest rate per year (%)', hint: 'e.g. 9'),
        _F('y', 'Time in years', hint: 'e.g. 5'),
      ],
      (i) {
        final n = i.n('y') * 12;
        if (n <= 0) return null;
        final r = i.n('r') / 12 / 100;
        final double emi;
        if (r == 0) {
          emi = i.n('p') / n;
        } else {
          final g = math.pow(1 + r, n).toDouble();
          emi = i.n('p') * r * g / (g - 1);
        }
        final total = emi * n;
        return [
          ['Monthly EMI / मासिक EMI', _fmt(emi)],
          ['Total payable / कुल भुगतान', _fmt(total)],
          ['Total interest / कुल ब्याज', _fmt(total - i.n('p'))],
        ];
      },
    ),
  ]),
  _Group('Average & Ratio / औसत और अनुपात', [
    _Calc(
      '📐',
      'Average',
      'औसत',
      'Average = Sum of all numbers ÷ How many numbers\nऔसत = सभी संख्याओं का योग ÷ संख्याओं की गिनती',
      const [_F('x', 'Numbers (separate with comma or space)', hint: 'e.g. 12, 18, 25, 30', list: true)],
      (i) {
        final v = i.l('x');
        if (v.isEmpty) return null;
        final sum = v.fold<double>(0, (a, b) => a + b);
        return [
          ['Average / औसत', _fmt(sum / v.length)],
          ['Sum / योग', _fmt(sum)],
          ['Count / गिनती', '${v.length}'],
          ['Highest / सबसे बड़ी', _fmt(v.reduce(math.max))],
          ['Lowest / सबसे छोटी', _fmt(v.reduce(math.min))],
        ];
      },
    ),
    _Calc(
      '⚖️',
      'Ratio split',
      'अनुपात में बाँटना',
      "Share of a part = Total × (its ratio) ÷ (sum of ratios)\nहिस्सा = कुल × (उसका अनुपात) ÷ (अनुपातों का योग)",
      const [
        _F('t', 'Total amount', hint: 'e.g. 12000'),
        _F('r', 'Ratio (separate with comma or space)', hint: 'e.g. 2, 3, 5', list: true),
      ],
      (i) {
        final r = i.l('r');
        if (r.length < 2 || r.length > 10 || r.any((e) => e < 0)) return null;
        final s = r.fold<double>(0, (a, b) => a + b);
        if (s <= 0) return null;
        return [
          for (var k = 0; k < r.length; k++) ['Part ${k + 1} / हिस्सा ${k + 1}  (${_fmt(r[k])})', _fmt(i.n('t') * r[k] / s)],
        ];
      },
    ),
  ]),
  _Group('Time, Work & Speed / समय, कार्य और चाल', [
    _Calc(
      '👷',
      'Time & Work (two people)',
      'समय और कार्य (दो व्यक्ति)',
      'Together = (A × B) ÷ (A + B) days\nसाथ में = (A × B) ÷ (A + B) दिन',
      const [_F('a', 'A alone takes (days)', hint: 'e.g. 12'), _F('b', 'B alone takes (days)', hint: 'e.g. 18')],
      (i) {
        if (i.n('a') <= 0 || i.n('b') <= 0) return null;
        final t = i.n('a') * i.n('b') / (i.n('a') + i.n('b'));
        return [
          ['Together take / साथ में समय', '${_fmt(t)} days / दिन'],
          ['Work done in 1 day / 1 दिन का काम', '${_fmt((1 / i.n('a') + 1 / i.n('b')) * 100)}%'],
        ];
      },
    ),
    _Calc(
      '🚆',
      'Speed, Distance, Time',
      'चाल, दूरी, समय',
      'Speed = Distance ÷ Time\nkm/h × 5/18 = m/s',
      const [_F('d', 'Distance (km)', hint: 'e.g. 150'), _F('t', 'Time (hours)', hint: 'e.g. 2.5')],
      (i) {
        if (i.n('t') <= 0) return null;
        final kmph = i.n('d') / i.n('t');
        return [
          ['Speed / चाल', '${_fmt(kmph)} km/h'],
          ['Speed in m/s', '${_fmt(kmph * 5 / 18)} m/s'],
        ];
      },
    ),
    _Calc(
      '🔁',
      'km/h ↔ m/s converter',
      'km/h ↔ m/s बदलें',
      'km/h → m/s : × 5/18\nm/s → km/h : × 18/5',
      const [_F('v', 'Speed value', hint: 'e.g. 72')],
      (i) => [
        ['If it is km/h → m/s', '${_fmt(i.n('v') * 5 / 18)} m/s'],
        ['If it is m/s → km/h', '${_fmt(i.n('v') * 18 / 5)} km/h'],
      ],
    ),
  ]),
];

/// Hub: saare calculators ki list.
class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Calculators / कैलकुलेटर')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text('Age & Eligibility / आयु और पात्रता', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
          _plainTile(context, '🎂', 'Age Calculator', 'उम्र और आयु-सीमा की जाँच', const AgeCalculatorScreen()),
          for (final g in _groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(g.title, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
            for (final c in g.calcs) _tile(context, c),
          ],
        ],
      ),
    );
  }

  Widget _plainTile(BuildContext context, String emoji, String title, String titleHi, Widget screen) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppC.line)),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(titleHi, style: TextStyle(color: AppC.text70, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppC.text54),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, _Calc c) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CalcPage(calc: c))),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppC.line)),
        child: Row(
          children: [
            Text(c.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(c.titleHi, style: TextStyle(color: AppC.text70, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppC.text54),
          ],
        ),
      ),
    );
  }
}

class _CalcPage extends StatefulWidget {
  final _Calc calc;
  const _CalcPage({required this.calc});

  @override
  State<_CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<_CalcPage> {
  late final Map<String, TextEditingController> _ctl = {
    for (final f in widget.calc.fields) f.key: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _num(String s) => double.tryParse(s.trim().replaceAll(',', ''));

  static List<double>? _numList(String s) {
    final parts = s.trim().split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final out = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p);
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  /// null = koi box abhi bhara nahi / galat likha hai.
  _In? _readInputs() {
    final m = <String, List<double>>{};
    for (final f in widget.calc.fields) {
      final raw = _ctl[f.key]!.text;
      final text = raw.trim().isEmpty ? (f.def ?? '') : raw;
      if (f.list) {
        final l = _numList(text);
        if (l == null) return null;
        m[f.key] = l;
      } else {
        final v = _num(text);
        if (v == null) return null;
        m[f.key] = [v];
      }
    }
    return _In(m);
  }

  Widget _resultView() {
    final inputs = _readInputs();
    if (inputs == null) {
      return Text('Fill in the values above to see the answer.\nजवाब देखने के लिए ऊपर वैल्यू भरें।', textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 12.5, height: 1.4));
    }
    List<List<String>>? rows;
    try {
      rows = widget.calc.compute(inputs);
    } catch (_) {
      rows = null;
    }
    if (rows == null || rows.isEmpty) {
      return Text('Please check the values (for example, no division by zero).\nकृपया वैल्यू जाँचें।', textAlign: TextAlign.center, style: TextStyle(color: AppC.red, fontSize: 12.5, height: 1.4));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var k = 0; k < rows.length; k++)
            Padding(
              padding: EdgeInsets.only(top: k == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(rows[k][0], style: const TextStyle(color: AppC.onGold, fontSize: 12.5, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Text(rows[k][1], style: TextStyle(color: AppC.onGold, fontSize: k == 0 ? 22 : 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.calc;
    return Scaffold(
      appBar: AppBar(title: Text(c.title, style: const TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppC.goldWash, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formula / सूत्र', style: TextStyle(color: AppC.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(c.formula, style: TextStyle(color: AppC.text, fontSize: 13, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final f in c.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _ctl[f.key],
                onChanged: (_) => setState(() {}),
                keyboardType: f.list ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: TextStyle(color: AppC.text, fontSize: 15),
                decoration: InputDecoration(
                  labelText: f.label,
                  labelStyle: TextStyle(color: AppC.text70, fontSize: 13),
                  hintText: f.hint,
                  hintStyle: TextStyle(color: AppC.text38, fontSize: 12.5),
                  filled: true,
                  fillColor: AppC.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          const SizedBox(height: 6),
          _resultView(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () {
                for (final t in _ctl.values) {
                  t.clear();
                }
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Clear / साफ़ करें'),
            ),
          ),
        ],
      ),
    );
  }
}
