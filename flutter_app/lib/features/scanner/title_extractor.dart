import '../../data/services/text_recognition_service.dart';

/// Picks the most likely game titles out of OCR lines from a box photo.
///
/// Box titles are usually the largest text on the front, so candidates are
/// ranked mainly by line height (a proxy for font size), after dropping box
/// boilerplate like "Ages 10+" or "2-4 players". Vertically stacked lines of
/// similar size are merged so two-line titles ("TICKET TO" / "RIDE") come
/// through whole.
///
/// Returns up to [maxCandidates] distinct titles, best first.
List<String> extractTitleCandidates(List<OcrLine> lines,
    {int maxCandidates = 3}) {
  final cleaned = <_Line>[];
  for (final line in lines) {
    final text = _clean(line.text);
    if (text != null) cleaned.add(_Line(text, line));
  }
  if (cleaned.isEmpty) return const [];

  // Ignore small print — anything well under the biggest text on the box.
  final maxHeight =
      cleaned.map((l) => l.box.height).reduce((a, b) => a > b ? a : b);
  final prominent = cleaned
      .where((l) => l.box.height >= maxHeight * _minRelativeHeight)
      .toList()
    ..sort((a, b) => a.box.top.compareTo(b.box.top));

  final scored = <_Candidate>[];
  for (final group in _groupStackedLines(prominent)) {
    final avgHeight =
        group.map((l) => l.box.height).reduce((a, b) => a + b) / group.length;
    final groupScore = avgHeight * _positionBonus(group.first.box);
    scored.add(_Candidate(group.map((l) => l.text).join(' '), groupScore));
    if (group.length > 1) {
      // Offer the individual lines too, in case the merge was wrong.
      for (final line in group) {
        scored.add(_Candidate(
            line.text, line.box.height * _positionBonus(line.box) * 0.7));
      }
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));

  final seen = <String>{};
  final results = <String>[];
  for (final c in scored) {
    final display = _displayCase(c.text);
    if (display.length > _maxTitleLength) continue;
    if (!seen.add(display.toLowerCase())) continue;
    results.add(display);
    if (results.length == maxCandidates) break;
  }
  return results;
}

const _minRelativeHeight = 0.3;
const _maxLineLength = 40;
const _maxTitleLength = 60;

class _Line {
  _Line(this.text, this.box);
  final String text;
  final OcrLine box;
}

class _Candidate {
  _Candidate(this.text, this.score);
  final String text;
  final double score;
}

/// Chains lines that sit directly above one another with a similar height and
/// overlapping horizontal span. [lines] must be sorted by top.
List<List<_Line>> _groupStackedLines(List<_Line> lines) {
  final groups = <List<_Line>>[];
  final used = <int>{};
  for (var i = 0; i < lines.length; i++) {
    if (used.contains(i)) continue;
    final group = [lines[i]];
    used.add(i);
    var last = lines[i];
    for (var j = i + 1; j < lines.length && group.length < 3; j++) {
      if (used.contains(j)) continue;
      final next = lines[j];
      if (_isStackedBelow(last.box, next.box)) {
        group.add(next);
        used.add(j);
        last = next;
      }
    }
    groups.add(group);
  }
  return groups;
}

bool _isStackedBelow(OcrLine upper, OcrLine lower) {
  final smaller =
      upper.height < lower.height ? upper.height : lower.height;
  final larger = upper.height > lower.height ? upper.height : lower.height;
  if (larger == 0 || smaller / larger < 0.75) return false;

  final gap = lower.top - upper.bottom;
  final avgHeight = (upper.height + lower.height) / 2;
  // OCR boxes hug the glyphs, so normal line spacing shows up as a gap of
  // roughly 0.5–0.8× the box height.
  if (gap < -avgHeight * 0.3 || gap > avgHeight) return false;

  final overlap = (upper.right < lower.right ? upper.right : lower.right) -
      (upper.left > lower.left ? upper.left : lower.left);
  return overlap > 0;
}

/// Small nudge towards text near the top and horizontal centre of the box.
double _positionBonus(OcrLine box) {
  final centerX = box.left + box.width / 2;
  final top = box.top.clamp(0.0, 1.0);
  return 1 + 0.15 * (1 - top) + 0.1 * (1 - ((centerX - 0.5).abs() * 2));
}

final _symbols = RegExp(r'[™®©]');
final _edgePunctuation =
    RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}!?')]+$", unicode: true);
final _letters = RegExp(r'\p{L}', unicode: true);
final _digits = RegExp(r'\d');
final _noise = RegExp(
  r'\d+\s*\+|\bages?\b|\bplayers?\b|\bmin(ute)?s?\b|\byears?\b'
  r'|www\.|https?:|\.com\b',
  caseSensitive: false,
);

/// Normalises a raw OCR line, or returns null if it's box boilerplate.
String? _clean(String raw) {
  final text = raw
      .replaceAll(_symbols, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(_edgePunctuation, '');
  if (text.isEmpty || text.length > _maxLineLength) return null;

  final letters = _letters.allMatches(text).length;
  final digits = _digits.allMatches(text).length;
  if (letters < 2) return null;
  if (digits > (letters + digits) * 0.4) return null;
  if (_noise.hasMatch(text)) return null;
  return text;
}

const _minorWords = {
  'a', 'an', 'and', 'as', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'the',
  'to', 'vs',
};
final _romanNumeral = RegExp(r'^[IVX]{1,4}$');

/// OCR on box art often comes back ALL CAPS; convert that to Title Case so the
/// confirmation field reads naturally. Mixed-case text is left alone.
String _displayCase(String text) {
  if (text != text.toUpperCase() || text == text.toLowerCase()) return text;
  final words = text.split(' ');
  return [
    for (var i = 0; i < words.length; i++) _titleWord(words[i], isFirst: i == 0)
  ].join(' ');
}

String _titleWord(String word, {required bool isFirst}) {
  if (word.isEmpty || _romanNumeral.hasMatch(word)) return word;
  final lower = word.toLowerCase();
  if (!isFirst && _minorWords.contains(lower)) return lower;
  return lower[0].toUpperCase() + lower.substring(1);
}
