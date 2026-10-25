/// Strips shop-listing noise from a product title returned by a barcode
/// lookup service, leaving something BoardGameGeek search can match.
///
/// e.g. "Catan Family Strategy Board Game: 5th Edition for Ages 10 and up
/// from Asmodee" → "Catan". The result only seeds an editable search field,
/// so it errs on the side of trimming. Returns the trimmed original if
/// cleaning would leave nothing.
String cleanRetailTitle(String raw) {
  var s = raw.replaceAll(RegExp(r'[™®©]'), '');

  // Bracketed asides: "(2-4 Players)", "[English Edition]".
  s = s.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');

  // Everything from audience / manufacturer phrases onwards.
  final tail = RegExp(
    r'\s(?:for\s+(?:ages|kids|adults|families|teens|\d)|ages?\s+\d|'
    r'from\s+\p{Lu}|by\s+\p{Lu}|\d+\s*(?:-|–|to)\s*\d+\s+players?)',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(s);
  if (tail != null) s = s.substring(0, tail.start);

  s = s
      // "Family Strategy Board Game", "Party Card Games", "Dice Game"
      .replaceAll(
          RegExp(
            r'\b(?:(?:family|strategy|cooperative|co-op|party|kids|classic|'
            r'award[- ]winning|fun)\s+)*(?:board|card|dice|tabletop)\s+games?\b',
            caseSensitive: false,
          ),
          ' ')
      // "5th Edition", "Second Edition", "Deluxe Edition"
      .replaceAll(
          RegExp(r'\b(?:\d+(?:st|nd|rd|th)|first|second|third|new|english)\s+edition\b',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'^\s*(?:buy|new)\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // Separators left dangling by the removals above: "Catan :" → "Catan".
      .replaceAll(RegExp(r'[\s:;,\-–|]+$'), '')
      .replaceAll(RegExp(r'^[\s:;,\-–|]+'), '');

  return s.isEmpty ? raw.trim() : s;
}
