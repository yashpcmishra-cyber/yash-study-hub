import 'package:flutter/material.dart';

/// Renders exam text with real textbook math formatting (no external package):
/// - Real raised superscripts for squares, cubes & powers: `(24.99)^2`, `(12.01)²`, `x^3`, `2^(n+1)`
/// - Real square root & cube root with top overbar (vinculum): `√625`, `√(125 + 44)`, `sqrt(625)`, `∛729`, `cbrt(729)`
/// - Real stacked vertical fractions with horizontal bar: `3/4`, `22/7`, `(x+2)/5`
///   (smartly ignores dates like `23/11/2026` and words/units like `PO/Clerk` or `km/hr`)
/// - Real operators: `×`, `÷`, `−`, `≥`, `≤`, `≠`
///
/// For plain text with no math tokens, falls back directly to a standard [Text] widget.
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const MathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  static final RegExp _quickMathCheck = RegExp(
    r'[\^√∛×÷²³⁴⁵⁶⁷⁸⁹⁰¹]|sqrt\s*\(|cbrt\s*\(|\d\s*/\s*\d|\)\s*/\s*\d|\d\s*/\s*\(|>=|<=|!=|\s\*\s|\d\*\d',
    caseSensitive: false,
  );

  /// Normalizes ASCII math operators while preserving normal English/Hindi prose.
  static String _normalizeOperators(String input) {
    var s = input;
    s = s.replaceAll('>=', '≥').replaceAll('<=', '≤').replaceAll('!=', '≠');
    // Multiply: between numbers, variables, or brackets
    s = s.replaceAllMapped(
      RegExp(r'([\d\)\]xXyY²³⁴⁵⁶⁷⁸⁹⁰¹])\s*\*\s*([\d\(\[xXyY√∛])'),
      (m) => '${m.group(1)} × ${m.group(2)}',
    );
    // Spaced divide operator: "48 / 6" or ") / (" -> "48 ÷ 6" (keeps tight fractions like "3/4" for vertical stacking)
    s = s.replaceAllMapped(
      RegExp(r'([\d\)\]²³⁴⁵⁶⁷⁸⁹⁰¹])\s+/\s+([\d\(\[√∛xXyY])'),
      (m) => '${m.group(1)} ÷ ${m.group(2)}',
    );
    // Clean minus sign between math terms
    s = s.replaceAllMapped(
      RegExp(r'([\d\)\]²³⁴⁵⁶⁷⁸⁹⁰¹xXyY])\s+-\s+([\d\(\[√∛xXyY])'),
      (m) => '${m.group(1)} − ${m.group(2)}',
    );
    return s;
  }

  static const Map<String, String> _uniSupToAscii = {
    '⁰': '0',
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    '⁻': '-',
    '⁺': '+',
    'ⁿ': 'n',
    'ˣ': 'x',
  };

  static String _decodeUniSup(String sup) =>
      sup.split('').map((c) => _uniSupToAscii[c] ?? c).join();

  /// Finds the index of the matching closing parenthesis for `s[openIdx] == '('`, or -1.
  static int _matchParen(String s, int openIdx) {
    var depth = 0;
    for (var i = openIdx; i < s.length; i++) {
      final ch = s[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Master tokenizer for:
  /// 1) Cube root: `∛(...)`, `cbrt(...)`, `∛123.45`
  /// 2) Square root: `√(...)`, `sqrt(...)`, `√123.45`
  /// 3) Stacked fraction: `12/25` or `(expr)/5` or `5/(expr)` (excluding dates `dd/mm/yyyy`)
  /// 4) Caret power: `^(...)` or `^-2` or `^2` or `^n`
  /// 5) Unicode superscripts: `²`, `³`, `⁻¹`, etc.
  static final RegExp _tokenStart = RegExp(
    r'(?:cbrt\s*\(|sqrt\s*\(|∛|√|\^\s*\(|\^-?[0-9a-zA-Z]+|[⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺ⁿˣ]+|(?<![\d/])(?:\([^()]{1,24}\)|\d+(?:\.\d+)?)/(?:\([^()]{1,24}\)|\d+(?:\.\d+)?)(?![\d/]))',
    caseSensitive: false,
  );

  List<InlineSpan> _parseSpans(String s, TextStyle baseStyle, int depth) {
    if (depth > 4 || s.isEmpty) return [TextSpan(text: s, style: baseStyle)];

    final spans = <InlineSpan>[];
    var cursor = 0;

    while (cursor < s.length) {
      final match = _tokenStart.firstMatch(s.substring(cursor));
      if (match == null) {
        spans.add(TextSpan(text: s.substring(cursor), style: baseStyle));
        break;
      }

      final start = cursor + match.start;
      final token = match.group(0)!;
      if (start > cursor) {
        spans.add(TextSpan(text: s.substring(cursor, start), style: baseStyle));
      }

      final lower = token.toLowerCase();

      // 1. Cube root or Square root with parenthesized radicand: sqrt(...) / cbrt(...) / √(...) / ∛(...)
      if (lower.startsWith('cbrt') || lower.startsWith('sqrt')) {
        final isCube = lower.startsWith('cbrt');
        final openIdx = s.indexOf('(', start);
        final closeIdx = openIdx >= 0 ? _matchParen(s, openIdx) : -1;
        if (closeIdx > openIdx) {
          final inner = s.substring(openIdx + 1, closeIdx).trim();
          spans.add(_rootSpan(inner, baseStyle, depth + 1, cube: isCube));
          cursor = closeIdx + 1;
          continue;
        }
      }

      if (token == '√' || token == '∛') {
        final isCube = token == '∛';
        final after = start + 1;
        if (after < s.length && s[after] == '(') {
          final closeIdx = _matchParen(s, after);
          if (closeIdx > after) {
            final inner = s.substring(after + 1, closeIdx).trim();
            spans.add(_rootSpan(inner, baseStyle, depth + 1, cube: isCube));
            cursor = closeIdx + 1;
            continue;
          }
        }
        // Simple number/variable radicand directly after √ or ∛ (e.g., √625, √24.5, √x)
        final numMatch = RegExp(r'^(?:\d+(?:\.\d+)?|[a-zA-Z])').firstMatch(s.substring(after));
        if (numMatch != null) {
          final inner = numMatch.group(0)!;
          spans.add(_rootSpan(inner, baseStyle, depth + 1, cube: isCube));
          cursor = after + inner.length;
          continue;
        }
        spans.add(TextSpan(text: token, style: baseStyle));
        cursor = after;
        continue;
      }

      // 2. Caret power with parentheses: ^(expr)
      if (token.startsWith('^') && token.endsWith('(')) {
        final openIdx = s.indexOf('(', start);
        final closeIdx = openIdx >= 0 ? _matchParen(s, openIdx) : -1;
        if (closeIdx > openIdx) {
          final exp = s.substring(openIdx + 1, closeIdx).trim();
          spans.add(_supSpan(exp, baseStyle, depth + 1));
          cursor = closeIdx + 1;
          continue;
        }
      }

      // 3. Simple caret power: ^2, ^3, ^-1, ^n
      if (token.startsWith('^') && token.length > 1) {
        final exp = token.substring(1);
        spans.add(_supSpan(exp, baseStyle, depth + 1));
        cursor = start + token.length;
        continue;
      }

      // 4. Unicode superscripts: ², ³, ⁻¹
      if (RegExp(r'^[⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺ⁿˣ]+$').hasMatch(token)) {
        spans.add(_supSpan(_decodeUniSup(token), baseStyle, depth + 1));
        cursor = start + token.length;
        continue;
      }

      // 5. Stacked vertical fraction: num/den
      final slashIdx = token.indexOf('/');
      if (slashIdx > 0 && slashIdx < token.length - 1) {
        var numStr = token.substring(0, slashIdx).trim();
        var denStr = token.substring(slashIdx + 1).trim();
        if (numStr.startsWith('(') && numStr.endsWith(')')) {
          numStr = numStr.substring(1, numStr.length - 1).trim();
        }
        if (denStr.startsWith('(') && denStr.endsWith(')')) {
          denStr = denStr.substring(1, denStr.length - 1).trim();
        }
        spans.add(_fractionSpan(numStr, denStr, baseStyle, depth + 1));
        cursor = start + token.length;
        continue;
      }

      spans.add(TextSpan(text: token, style: baseStyle));
      cursor = start + token.length;
    }

    return spans;
  }

  /// Raised superscript widget span.
  WidgetSpan _supSpan(String exp, TextStyle baseStyle, int depth) {
    final baseSize = baseStyle.fontSize ?? 15.0;
    final supStyle = baseStyle.copyWith(fontSize: baseSize * 0.68, height: 1.0);
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Transform.translate(
        offset: Offset(0, -baseSize * 0.12),
        child: Padding(
          padding: const EdgeInsets.only(left: 0.5, right: 1),
          child: Text.rich(
            TextSpan(children: _parseSpans(exp, supStyle, depth)),
            style: supStyle,
          ),
        ),
      ),
    );
  }

  /// Square root / cube root with real top horizontal overbar (vinculum).
  WidgetSpan _rootSpan(String radicand, TextStyle baseStyle, int depth, {bool cube = false}) {
    final baseSize = baseStyle.fontSize ?? 15.0;
    final color = baseStyle.color ?? Colors.black;
    final innerStyle = baseStyle.copyWith(fontSize: baseSize * 0.94, height: 1.15);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (cube)
              Transform.translate(
                offset: Offset(2, -baseSize * 0.42),
                child: Text(
                  '3',
                  style: baseStyle.copyWith(fontSize: baseSize * 0.56, fontWeight: FontWeight.bold, height: 1.0),
                ),
              ),
            Text(
              '√',
              style: baseStyle.copyWith(fontSize: baseSize * 1.18, height: 1.0, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: const EdgeInsets.only(left: 2, right: 3, top: 1),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: color, width: 1.25)),
              ),
              child: Text.rich(
                TextSpan(children: _parseSpans(radicand, innerStyle, depth)),
                style: innerStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stacked vertical fraction with horizontal divider bar.
  WidgetSpan _fractionSpan(String numStr, String denStr, TextStyle baseStyle, int depth) {
    final baseSize = baseStyle.fontSize ?? 15.0;
    final color = baseStyle.color ?? Colors.black;
    final fracStyle = baseStyle.copyWith(fontSize: baseSize * 0.78, height: 1.08);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text.rich(
                  TextSpan(children: _parseSpans(numStr, fracStyle, depth)),
                  style: fracStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                height: 1.2,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                color: color,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text.rich(
                  TextSpan(children: _parseSpans(denStr, fracStyle, depth)),
                  style: fracStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    if (!_quickMathCheck.hasMatch(text)) {
      return Text(text, style: style, textAlign: textAlign);
    }
    final normalized = _normalizeOperators(text);
    final spans = _parseSpans(normalized, effectiveStyle, 0);
    return Text.rich(
      TextSpan(children: spans),
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }
}
