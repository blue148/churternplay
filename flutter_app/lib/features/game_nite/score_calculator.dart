// Pure logic behind the Game Nite score calculator, kept free of Flutter so
// it can be unit-tested.

/// Evaluates an expression of numbers with `+ − × ÷` (also `-`, `*`, `/`),
/// decimals and a leading unary minus, honouring × ÷ before + −.
///
/// Returns null when the expression is empty, incomplete (e.g. `5+`),
/// malformed, or divides by zero.
double? evaluateExpression(String input) {
  final src = input
      .replaceAll('−', '-')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll(' ', '');
  if (src.isEmpty) return null;

  var pos = 0;
  var failed = false;

  double? number() {
    var negative = false;
    while (pos < src.length && (src[pos] == '-' || src[pos] == '+')) {
      if (src[pos] == '-') negative = !negative;
      pos++;
    }
    final start = pos;
    while (pos < src.length && (_isDigit(src[pos]) || src[pos] == '.')) {
      pos++;
    }
    if (pos == start) {
      failed = true;
      return null;
    }
    final value = double.tryParse(src.substring(start, pos));
    if (value == null) {
      failed = true;
      return null;
    }
    return negative ? -value : value;
  }

  double? term() {
    var left = number();
    while (!failed && pos < src.length && (src[pos] == '*' || src[pos] == '/')) {
      final op = src[pos++];
      final right = number();
      if (failed || left == null || right == null) {
        failed = true;
        return null;
      }
      if (op == '/' && right == 0) {
        failed = true;
        return null;
      }
      left = op == '*' ? left * right : left / right;
    }
    return left;
  }

  var total = term();
  while (!failed && pos < src.length && (src[pos] == '+' || src[pos] == '-')) {
    final op = src[pos++];
    final right = term();
    if (failed || total == null || right == null) return null;
    total = op == '+' ? total + right : total - right;
  }
  if (failed || pos != src.length) return null;
  return total;
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

/// Formats a score: whole numbers without a decimal point, otherwise up to
/// two decimals with trailing zeros trimmed.
String formatScore(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  var s = rounded.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

/// One player on the calculator board. [entries] are the amounts added to
/// them, in order; the total is their sum.
class ScorePlayer {
  ScorePlayer({required this.id, required this.name});

  final int id;
  final String name;
  final List<double> entries = [];

  double get total => entries.fold(0.0, (a, b) => a + b);
}
