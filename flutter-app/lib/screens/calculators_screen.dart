import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'age_calculator_screen.dart';

// =============================================================================
//  Quick Calculators - exam ke kaam aane wale chhote calculators (Percentage,
//  Profit & Loss, Discount, SI / CI, EMI, Average, Ratio, Time & Work,
//  Speed, Exam Marks, GST / FD / RD, Boats, Pipes, Train, Alligation,
//  Calendar & Clock, HCF / LCM, Unit converters). Har calculator formula bhi
//  dikhata hai. Pura offline - kuch save nahi hota, Firestore ko 0 reads / 0 writes.
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

bool _isInt(double v) => !v.isNaN && !v.isInfinite && v == v.roundToDouble();

bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// Sahi tareekh ho to DateTime (UTC), warna null (jaise 31 February).
DateTime? _mkDate(double y, double m, double d) {
  if (!_isInt(y) || !_isInt(m) || !_isInt(d)) return null;
  final yy = y.toInt();
  final mm = m.toInt();
  final dd = d.toInt();
  if (yy < 1 || yy > 9999 || mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
  final t = DateTime.utc(yy, mm, dd);
  if (t.year != yy || t.month != mm || t.day != dd) return null;
  return t;
}

const List<String> _dayEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const List<String> _dayHi = ['सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार'];

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
  _Group('Exam Marks & Time / परीक्षा अंक और समय', [
    _Calc(
      '🎯',
      'Score with negative marking',
      'नेगेटिव मार्किंग के साथ स्कोर',
      'Score = (Correct × marks) − (Wrong × negative)\nSSC: +2 / −0.5  •  Bank prelims: +1 / −0.25  •  RRB NTPC: +1 / −0.33\n(Check the marking scheme of your own exam.)\nस्कोर = (सही × अंक) − (गलत × नेगेटिव)',
      const [
        _F('q', 'Total questions', hint: 'e.g. 100'),
        _F('c', 'Correct answers', hint: 'e.g. 62'),
        _F('w', 'Wrong answers', hint: 'e.g. 18'),
        _F('m', 'Marks per correct answer', hint: 'SSC = 2, Bank = 1', def: '1'),
        _F('n', 'Negative marks per wrong answer', hint: 'SSC = 0.5, Bank = 0.25', def: '0.25'),
      ],
      (i) {
        final q = i.n('q'), c = i.n('c'), w = i.n('w'), m = i.n('m'), n = i.n('n');
        if (q <= 0 || c < 0 || w < 0 || m <= 0 || n < 0 || c + w > q) return null;
        final score = c * m - w * n;
        final att = c + w;
        return [
          ['Your score / आपका स्कोर', _fmt(score)],
          ['Out of / कुल अंक', _fmt(q * m)],
          ['Percentage / प्रतिशत', '${_fmt(score / (q * m) * 100)}%'],
          ['Accuracy / सटीकता', att == 0 ? '--' : '${_fmt(c / att * 100)}%'],
          ['Attempted / किए गए', _fmt(att)],
          ['Not attempted / छोड़े गए', _fmt(q - att)],
        ];
      },
    ),
    _Calc(
      '🚧',
      'Cut-off gap',
      'कट-ऑफ से अंतर',
      'Gap = Your score − Cut-off\nगैप = आपका स्कोर − कट-ऑफ',
      const [_F('s', 'Your score', hint: 'e.g. 128.5'), _F('c', 'Cut-off marks', hint: 'e.g. 135')],
      (i) {
        if (i.n('c') <= 0) return null;
        final d = i.n('s') - i.n('c');
        return [
          [d >= 0 ? 'Above the cut-off by / कट-ऑफ से ऊपर' : 'Short of the cut-off by / कट-ऑफ से कम', _fmt(d.abs())],
          ['Your score as % of cut-off / कट-ऑफ का %', '${_fmt(i.n('s') / i.n('c') * 100)}%'],
        ];
      },
    ),
    _Calc(
      '⏱️',
      'Time per question',
      'प्रति प्रश्न समय',
      'Time per question = (Total time − revision time) × 60 ÷ Questions\nप्रति प्रश्न समय = (कुल समय − दोहराने का समय) × 60 ÷ प्रश्न',
      const [
        _F('q', 'Number of questions', hint: 'e.g. 100'),
        _F('t', 'Total time (minutes)', hint: 'e.g. 60'),
        _F('b', 'Minutes kept for revision (optional)', hint: 'leave empty if none', def: '0'),
      ],
      (i) {
        final use = i.n('t') - i.n('b');
        if (i.n('q') <= 0 || use <= 0) return null;
        return [
          ['Per question / प्रति प्रश्न', '${_fmt(use * 60 / i.n('q'))} sec'],
          ['Questions per minute / प्रश्न प्रति मिनट', _fmt(i.n('q') / use)],
        ];
      },
    ),
  ]),
  _Group('Banking & Money / बैंकिंग और पैसा', [
    _Calc(
      '🧾',
      'GST (add / remove)',
      'GST जोड़ें / हटाएँ',
      'GST = Amount × Rate ÷ 100\nPrice with GST = Amount × (100 + Rate) ÷ 100\nBase price from GST-inclusive = Amount × 100 ÷ (100 + Rate)',
      const [_F('a', 'Amount', hint: 'e.g. 2500'), _F('r', 'GST rate (%)', hint: 'common: 5, 12, 18, 28', def: '18')],
      (i) {
        final a = i.n('a'), r = i.n('r');
        if (a < 0 || r < 0) return null;
        final base = a * 100 / (100 + r);
        return [
          ['GST on this amount / इस राशि पर GST', _fmt(a * r / 100)],
          ['Total with GST / GST सहित कुल', _fmt(a * (100 + r) / 100)],
          ['If amount already has GST: base / GST-रहित मूल्य', _fmt(base)],
          ['If amount already has GST: GST / उसमें GST', _fmt(a - base)],
        ];
      },
    ),
    _Calc(
      '💰',
      'FD maturity (quarterly)',
      'FD परिपक्वता (तिमाही)',
      'Amount = P × (1 + R ÷ 400)^(4 × T)\nBanks usually compound FD interest every quarter.\nबैंक आमतौर पर FD का ब्याज हर तिमाही जोड़ते हैं।',
      const [
        _F('p', 'Deposit amount (P)', hint: 'e.g. 100000'),
        _F('r', 'Interest rate per year (%)', hint: 'e.g. 7'),
        _F('t', 'Time in years (T)', hint: 'e.g. 3'),
      ],
      (i) {
        if (i.n('p') <= 0 || i.n('r') < 0 || i.n('t') <= 0) return null;
        final amt = i.n('p') * math.pow(1 + i.n('r') / 400, 4 * i.n('t')).toDouble();
        return [
          ['Maturity amount / परिपक्वता राशि', _fmt(amt)],
          ['Interest earned / कुल ब्याज', _fmt(amt - i.n('p'))],
        ];
      },
    ),
    _Calc(
      '🐖',
      'RD maturity (monthly deposit)',
      'RD परिपक्वता (मासिक जमा)',
      'Maturity = R × [(1 + i)^n − 1] ÷ [1 − (1 + i)^(−1/3)]\ni = rate ÷ 400,  n = months ÷ 3   (quarterly compounding)',
      const [
        _F('p', 'Monthly deposit (R)', hint: 'e.g. 2000'),
        _F('r', 'Interest rate per year (%)', hint: 'e.g. 6.5'),
        _F('m', 'Time in months', hint: 'e.g. 24'),
      ],
      (i) {
        final p = i.n('p'), rate = i.n('r'), mo = i.n('m');
        if (p <= 0 || rate < 0 || mo <= 0) return null;
        final inv = p * mo;
        final double mat;
        if (rate == 0) {
          mat = inv;
        } else {
          final q = rate / 400;
          final n = mo / 3;
          mat = p * (math.pow(1 + q, n).toDouble() - 1) / (1 - math.pow(1 + q, -1 / 3).toDouble());
        }
        return [
          ['Maturity amount / परिपक्वता राशि', _fmt(mat)],
          ['Total deposited / कुल जमा', _fmt(inv)],
          ['Interest earned / कुल ब्याज', _fmt(mat - inv)],
        ];
      },
    ),
    _Calc(
      '📌',
      'Marked price for target profit',
      'लक्ष्य लाभ के लिए अंकित मूल्य',
      'MP = CP × (100 + Profit%) ÷ (100 − Discount%)\nअंकित मूल्य = क्रय × (100 + लाभ%) ÷ (100 − छूट%)',
      const [
        _F('cp', 'Cost Price (CP)', hint: 'e.g. 800'),
        _F('p', 'Profit you want (%)', hint: 'e.g. 20'),
        _F('d', 'Discount you will give (%)', hint: 'e.g. 10'),
      ],
      (i) {
        if (i.n('cp') <= 0 || i.n('d') < 0 || i.n('d') >= 100) return null;
        return [
          ['Marked Price / अंकित मूल्य', _fmt(i.n('cp') * (100 + i.n('p')) / (100 - i.n('d')))],
          ['Selling Price / विक्रय मूल्य', _fmt(i.n('cp') * (100 + i.n('p')) / 100)],
        ];
      },
    ),
  ]),
  _Group('More Speed & Work / और चाल व कार्य', [
    _Calc(
      '🚗',
      'Average speed (same distance)',
      'औसत चाल (समान दूरी)',
      'Average speed = 2 × S1 × S2 ÷ (S1 + S2)\nऔसत चाल = 2 × S1 × S2 ÷ (S1 + S2)',
      const [_F('a', 'Speed one way (km/h)', hint: 'e.g. 40'), _F('b', 'Speed on the way back (km/h)', hint: 'e.g. 60')],
      (i) {
        if (i.n('a') <= 0 || i.n('b') <= 0) return null;
        return [
          ['Average speed / औसत चाल', '${_fmt(2 * i.n('a') * i.n('b') / (i.n('a') + i.n('b')))} km/h'],
        ];
      },
    ),
    _Calc(
      '🚂',
      'Train crossing time',
      'ट्रेन के पार करने का समय',
      'Time = (Length of train + Length of other) ÷ Relative speed\nOpposite: add the speeds.  Same direction: subtract the speeds.\nFor a pole / platform / standing person, keep the other speed 0.',
      const [
        _F('l1', 'Length of train (metres)', hint: 'e.g. 150'),
        _F('s1', 'Speed of train (km/h)', hint: 'e.g. 72'),
        _F('l2', 'Length of other train / platform (m)', hint: 'e.g. 100', def: '0'),
        _F('s2', 'Speed of other train (km/h)', hint: '0 for pole / platform', def: '0'),
      ],
      (i) {
        final l1 = i.n('l1'), s1 = i.n('s1'), l2 = i.n('l2'), s2 = i.n('s2');
        if (l1 <= 0 || s1 <= 0 || l2 < 0 || s2 < 0) return null;
        final dist = l1 + l2;
        return [
          ['Opposite direction / उल्टी दिशा', '${_fmt(dist / ((s1 + s2) * 5 / 18))} sec'],
          ['Same direction / एक ही दिशा', s1 > s2 ? '${_fmt(dist / ((s1 - s2) * 5 / 18))} sec' : '-- (never)'],
        ];
      },
    ),
    _Calc(
      '🚤',
      'Boat: downstream & upstream',
      'नाव: धारा के साथ और विरुद्ध',
      'Downstream = Boat + Stream\nUpstream = Boat − Stream\nनाव की चाल (शांत जल में) = B, धारा की चाल = S',
      const [_F('b', 'Boat speed in still water (km/h)', hint: 'e.g. 12'), _F('s', 'Stream speed (km/h)', hint: 'e.g. 3')],
      (i) {
        if (i.n('b') <= 0 || i.n('s') < 0) return null;
        return [
          ['Downstream / धारा के साथ', '${_fmt(i.n('b') + i.n('s'))} km/h'],
          ['Upstream / धारा के विरुद्ध', '${_fmt(i.n('b') - i.n('s'))} km/h'],
        ];
      },
    ),
    _Calc(
      '🌊',
      'Boat & stream from down / up speed',
      'डाउन / अप चाल से नाव व धारा',
      'Boat speed = (Downstream + Upstream) ÷ 2\nStream speed = (Downstream − Upstream) ÷ 2',
      const [_F('d', 'Downstream speed (km/h)', hint: 'e.g. 15'), _F('u', 'Upstream speed (km/h)', hint: 'e.g. 9')],
      (i) {
        if (i.n('u') < 0 || i.n('d') < i.n('u')) return null;
        return [
          ['Boat in still water / शांत जल में नाव', '${_fmt((i.n('d') + i.n('u')) / 2)} km/h'],
          ['Stream / धारा', '${_fmt((i.n('d') - i.n('u')) / 2)} km/h'],
        ];
      },
    ),
    _Calc(
      '🚰',
      'Pipes & Cisterns',
      'पाइप और टंकी',
      'Net work in 1 hour = 1/A + 1/B − 1/C\nTime to fill = 1 ÷ (net work in 1 hour)\nC is the emptying pipe (keep 0 if there is none).',
      const [
        _F('a', 'Pipe A fills alone in (hours)', hint: 'e.g. 12'),
        _F('b', 'Pipe B fills alone in (hours)', hint: 'e.g. 15'),
        _F('c', 'Pipe C empties alone in (hours)', hint: '0 if there is no emptying pipe', def: '0'),
      ],
      (i) {
        final a = i.n('a'), b = i.n('b'), c = i.n('c');
        if (a <= 0 || b <= 0 || c < 0) return null;
        final rate = 1 / a + 1 / b - (c > 0 ? 1 / c : 0);
        if (rate <= 0) {
          return [
            ['Result / नतीजा', 'Never fills / कभी नहीं भरेगा'],
          ];
        }
        return [
          ['Time to fill / भरने का समय', '${_fmt(1 / rate)} hours / घंटे'],
        ];
      },
    ),
    _Calc(
      '🧪',
      'Mixture (Alligation)',
      'मिश्रण (एलिगेशन)',
      'Cheaper : Dearer = (Dearer − Mean) : (Mean − Cheaper)\nसस्ता : महँगा = (महँगा − मध्य) : (मध्य − सस्ता)',
      const [
        _F('c', 'Price of the cheaper item', hint: 'e.g. 40'),
        _F('d', 'Price of the dearer item', hint: 'e.g. 60'),
        _F('m', 'Mean (mixture) price', hint: 'e.g. 48'),
      ],
      (i) {
        final c = i.n('c'), d = i.n('d'), m = i.n('m');
        if (!(c < m && m < d)) return null;
        final a = d - m, b = m - c;
        return [
          ['Cheaper : Dearer / सस्ता : महँगा', '${_fmt(a)} : ${_fmt(b)}'],
          ['Cheaper item share / सस्ते का हिस्सा', '${_fmt(a / (a + b) * 100)}%'],
        ];
      },
    ),
  ]),
  _Group('Calendar & Clock / कैलेंडर और घड़ी', [
    _Calc(
      '📆',
      'Day of the week',
      'तारीख से वार',
      'Enter any date to see which weekday it was / will be.\nकोई भी तारीख डालें, उसका वार (दिन) देखें।',
      const [
        _F('d', 'Day (1-31)', hint: 'e.g. 15'),
        _F('m', 'Month (1-12)', hint: 'e.g. 8'),
        _F('y', 'Year', hint: 'e.g. 1947'),
      ],
      (i) {
        final t = _mkDate(i.n('y'), i.n('m'), i.n('d'));
        if (t == null) return null;
        final wd = t.weekday - 1;
        final doy = t.difference(DateTime.utc(t.year, 1, 1)).inDays + 1;
        return [
          ['Day / वार', '${_dayEn[wd]} / ${_dayHi[wd]}'],
          ['Day number of the year / वर्ष का दिन', '$doy'],
          ['Leap year? / लीप वर्ष?', _isLeap(t.year) ? 'Yes / हाँ' : 'No / नहीं'],
        ];
      },
    ),
    _Calc(
      '🗓️',
      'Days between two dates',
      'दो तारीखों के बीच के दिन',
      'Gives the gap in days, weeks and years-months-days.\nदिन, सप्ताह और वर्ष-माह-दिन में अंतर बताता है।',
      const [
        _F('d1', 'From: Day', hint: 'e.g. 26'),
        _F('m1', 'From: Month (1-12)', hint: 'e.g. 1'),
        _F('y1', 'From: Year', hint: 'e.g. 1950'),
        _F('d2', 'To: Day', hint: 'e.g. 15'),
        _F('m2', 'To: Month (1-12)', hint: 'e.g. 8'),
        _F('y2', 'To: Year', hint: 'e.g. 2026'),
      ],
      (i) {
        final a = _mkDate(i.n('y1'), i.n('m1'), i.n('d1'));
        final b = _mkDate(i.n('y2'), i.n('m2'), i.n('d2'));
        if (a == null || b == null) return null;
        final from = a.isAfter(b) ? b : a;
        final to = a.isAfter(b) ? a : b;
        final days = to.difference(from).inDays;
        var y = to.year - from.year;
        var m = to.month - from.month;
        var d = to.day - from.day;
        if (d < 0) {
          m--;
          d += DateTime.utc(to.year, to.month, 0).day;
        }
        if (m < 0) {
          y--;
          m += 12;
        }
        return [
          ['Days between / बीच के दिन', '$days'],
          ['Counting both dates / दोनों तारीखें गिनकर', '${days + 1}'],
          ['Weeks & days / सप्ताह और दिन', '${days ~/ 7} w ${days % 7} d'],
          ['Years-Months-Days / वर्ष-माह-दिन', '$y y $m m $d d'],
        ];
      },
    ),
    _Calc(
      '🕐',
      'Clock angle',
      'घड़ी का कोण',
      'Angle = |30 × H − 5.5 × M|   (use the smaller angle, if above 180° take 360° − angle)\nकोण = |30 × घंटा − 5.5 × मिनट|',
      const [_F('h', 'Hour (0-12)', hint: 'e.g. 3'), _F('m', 'Minutes (0-59)', hint: 'e.g. 40')],
      (i) {
        final h = i.n('h'), m = i.n('m');
        if (h < 0 || h > 12 || m < 0 || m >= 60) return null;
        var ang = (30 * (h % 12) + 0.5 * m - 6 * m).abs();
        if (ang > 180) ang = 360 - ang;
        return [
          ['Angle between hands / हाथों के बीच कोण', '${_fmt(ang)}°'],
          ['Other side / दूसरी ओर', '${_fmt(360 - ang)}°'],
        ];
      },
    ),
    _Calc(
      '🔮',
      'Leap year check',
      'लीप वर्ष जाँच',
      'Leap year: divisible by 4, but a century year must be divisible by 400.\nलीप वर्ष: 4 से विभाज्य; शताब्दी वर्ष 400 से विभाज्य होना चाहिए।',
      const [_F('y', 'Year', hint: 'e.g. 2100')],
      (i) {
        final y = i.n('y');
        if (!_isInt(y) || y < 1 || y > 9998) return null;
        final yy = y.toInt();
        var next = yy + 1;
        while (!_isLeap(next)) {
          next++;
        }
        return [
          ['Leap year? / लीप वर्ष?', _isLeap(yy) ? 'Yes / हाँ' : 'No / नहीं'],
          ['Next leap year / अगला लीप वर्ष', '$next'],
          ['Days in February / फरवरी में दिन', _isLeap(yy) ? '29' : '28'],
        ];
      },
    ),
  ]),
  _Group('Number Tools / संख्या टूल', [
    _Calc(
      '🔗',
      'HCF & LCM',
      'म.स. (HCF) और ल.स. (LCM)',
      'HCF = greatest number that divides all the numbers.\nLCM = smallest number that all of them divide.\nमहत्तम समापवर्तक (म.स.) और लघुत्तम समापवर्त्य (ल.स.)',
      const [_F('x', 'Numbers (2 to 10, whole numbers)', hint: 'e.g. 12, 18, 30', list: true)],
      (i) {
        final v = i.l('x');
        if (v.length < 2 || v.length > 10 || v.any((e) => e < 1 || e > 1e9 || !_isInt(e))) return null;
        var g = BigInt.from(v.first.toInt());
        var l = g;
        for (final e in v.skip(1)) {
          final b = BigInt.from(e.toInt());
          g = g.gcd(b);
          l = (l ~/ l.gcd(b)) * b;
        }
        return [
          ['HCF / म.स.', g.toString()],
          ['LCM / ल.स.', l.toString()],
        ];
      },
    ),
    _Calc(
      '🧬',
      'Prime factors & number of factors',
      'अभाज्य गुणनखंड और गुणनखंडों की संख्या',
      'Number of factors: if N = a^p × b^q × c^r then factors = (p+1)(q+1)(r+1)\nसंख्या N = a^p × b^q × c^r हो तो गुणनखंड = (p+1)(q+1)(r+1)',
      const [_F('n', 'Number (2 to 1,000,000,000,000)', hint: 'e.g. 360')],
      (i) {
        final x = i.n('n');
        if (!_isInt(x) || x < 2 || x > 1e12) return null;
        var n = x.toInt();
        final parts = <String>[];
        var count = 1;
        var p = 2;
        while (p * p <= n) {
          if (n % p == 0) {
            var e = 0;
            while (n % p == 0) {
              n ~/= p;
              e++;
            }
            parts.add(e == 1 ? '$p' : '$p^$e');
            count *= (e + 1);
          }
          p += (p == 2) ? 1 : 2;
        }
        if (n > 1) {
          parts.add('$n');
          count *= 2;
        }
        final isPrime = parts.length == 1 && !parts.first.contains('^');
        return [
          ['Prime factors / अभाज्य गुणनखंड', parts.join(' × ')],
          ['Number of factors / गुणनखंडों की संख्या', '$count'],
          ['Is it prime? / क्या अभाज्य है?', isPrime ? 'Yes / हाँ' : 'No / नहीं'],
        ];
      },
    ),
    _Calc(
      '🔟',
      'Last digit / remainder of a^b',
      'a^b का इकाई अंक / शेषफल',
      'Remainder of a^b ÷ m.   With m = 10 you get the LAST DIGIT of a^b.\nm = 10 रखने पर a^b का इकाई अंक मिलता है।',
      const [
        _F('a', 'Base (a)', hint: 'e.g. 7'),
        _F('b', 'Power (b)', hint: 'e.g. 2026'),
        _F('m', 'Divide by (m)', hint: '10 = last digit', def: '10'),
      ],
      (i) {
        final a = i.n('a'), b = i.n('b'), m = i.n('m');
        if (!_isInt(a) || !_isInt(b) || !_isInt(m) || a < 0 || b < 0 || m < 1 || a > 1e15 || b > 1e15 || m > 1e9) return null;
        final r = BigInt.from(a.toInt()).modPow(BigInt.from(b.toInt()), BigInt.from(m.toInt()));
        return [
          ['Remainder / शेषफल', r.toString()],
        ];
      },
    ),
  ]),
  _Group('Unit Converters / इकाई बदलें', [
    _Calc(
      '🛣️',
      'Kilometres ↔ Miles',
      'किलोमीटर ↔ मील',
      '1 mile = 1.609344 km\nमील → km : × 1.609344      km → मील : ÷ 1.609344',
      const [_F('v', 'Value', hint: 'e.g. 100')],
      (i) => [
        ['If it is km → miles', '${_fmt(i.n('v') / 1.609344)} mi'],
        ['If it is miles → km', '${_fmt(i.n('v') * 1.609344)} km'],
      ],
    ),
    _Calc(
      '🏋️',
      'Kilograms ↔ Pounds',
      'किलोग्राम ↔ पाउंड',
      '1 kg = 2.20462 lb',
      const [_F('v', 'Value', hint: 'e.g. 70')],
      (i) => [
        ['If it is kg → pounds', '${_fmt(i.n('v') * 2.20462)} lb'],
        ['If it is pounds → kg', '${_fmt(i.n('v') / 2.20462)} kg'],
      ],
    ),
    _Calc(
      '🌡️',
      'Celsius ↔ Fahrenheit',
      'सेल्सियस ↔ फॉरेनहाइट',
      '°F = °C × 9/5 + 32\n°C = (°F − 32) × 5/9',
      const [_F('v', 'Temperature', hint: 'e.g. 37')],
      (i) => [
        ['If it is °C → °F', '${_fmt(i.n('v') * 9 / 5 + 32)} °F'],
        ['If it is °F → °C', '${_fmt((i.n('v') - 32) * 5 / 9)} °C'],
      ],
    ),
    _Calc(
      '📏',
      'Metres ↔ Feet',
      'मीटर ↔ फ़ुट',
      '1 metre = 3.28084 feet     1 foot = 12 inches',
      const [_F('v', 'Value', hint: 'e.g. 100')],
      (i) => [
        ['If it is metres → feet', '${_fmt(i.n('v') * 3.28084)} ft'],
        ['If it is feet → metres', '${_fmt(i.n('v') / 3.28084)} m'],
      ],
    ),
    _Calc(
      '🌾',
      'Acre ↔ Hectare',
      'एकड़ ↔ हेक्टेयर',
      '1 hectare = 10,000 sq m = 2.47105 acre\n1 acre = 4046.86 sq m',
      const [_F('v', 'Value', hint: 'e.g. 5')],
      (i) => [
        ['If it is acres → hectares', '${_fmt(i.n('v') * 0.404686)} ha'],
        ['If it is acres → sq metres', '${_fmt(i.n('v') * 4046.86)} sq m'],
        ['If it is hectares → acres', '${_fmt(i.n('v') * 2.47105)} acre'],
      ],
    ),
  ]),
];

/// Hub: saare calculators ki list (upar search box se dhoondh sakte hain).
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  String _q = '';

  bool _match(_Calc c) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.title.toLowerCase().contains(q) || c.titleHi.contains(_q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final showAge = q.isEmpty || 'age calculator'.contains(q) || 'उम्र और आयु-सीमा की जाँच'.contains(_q.trim());
    final shown = <Widget>[];
    var found = showAge;
    if (showAge) {
      shown.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text('Age & Eligibility / आयु और पात्रता', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
      ));
      shown.add(_plainTile(context, '🎂', 'Age Calculator', 'उम्र और आयु-सीमा की जाँच', const AgeCalculatorScreen()));
    }
    for (final g in _groups) {
      final hits = g.calcs.where(_match).toList();
      if (hits.isEmpty) continue;
      found = true;
      shown.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(g.title, style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 13.5)),
      ));
      for (final c in hits) {
        shown.add(_tile(context, c));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Calculators / कैलकुलेटर')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            onChanged: (v) => setState(() => _q = v),
            style: TextStyle(color: AppC.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search a calculator / कैलकुलेटर खोजें',
              hintStyle: TextStyle(color: AppC.text38, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: AppC.text54),
              filled: true,
              fillColor: AppC.card,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          ...shown,
          if (!found)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('No calculator found.\nकोई कैलकुलेटर नहीं मिला।', textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 13, height: 1.4)),
            ),
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
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                    child: Text(rows[k][1], textAlign: TextAlign.right, style: TextStyle(color: AppC.onGold, fontSize: k == 0 ? 22 : 16, fontWeight: FontWeight.bold)),
                  ),
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
