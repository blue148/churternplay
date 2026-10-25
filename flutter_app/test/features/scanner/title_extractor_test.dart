import 'package:churntern_play/data/services/text_recognition_service.dart';
import 'package:churntern_play/features/scanner/title_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLine line(String text,
        {double left = 0.2,
        double top = 0.1,
        double width = 0.6,
        double height = 0.08}) =>
    OcrLine(text: text, left: left, top: top, width: width, height: height);

void main() {
  group('extractTitleCandidates', () {
    test('returns empty for no lines', () {
      expect(extractTitleCandidates(const []), isEmpty);
    });

    test('picks the largest line as the title', () {
      final result = extractTitleCandidates([
        line('A game of trains and routes', top: 0.05, height: 0.03),
        line('Wingspan', top: 0.2, height: 0.12),
        line('Stonemaier Games', top: 0.85, height: 0.04),
      ]);
      expect(result.first, 'Wingspan');
    });

    test('merges a title split across two stacked lines', () {
      final result = extractTitleCandidates([
        line('TICKET TO', top: 0.10, height: 0.10),
        line('RIDE', left: 0.35, top: 0.22, width: 0.3, height: 0.10),
        line('Days of Wonder', top: 0.9, height: 0.03),
      ]);
      expect(result.first, 'Ticket to Ride');
    });

    test('merges stacked lines with real Vision line spacing', () {
      // Boxes measured from Apple Vision on a rendered two-line title.
      final result = extractTitleCandidates([
        line('TICKET TO', left: 0.10, top: 0.09, width: 0.62, height: 0.08),
        line('RIDE', left: 0.11, top: 0.22, width: 0.30, height: 0.08),
        line('Ages 8+ 2-5 Players', left: 0.10, top: 0.85, height: 0.03),
      ]);
      expect(result.first, 'Ticket to Ride');
    });

    test('does not merge lines far apart', () {
      final result = extractTitleCandidates([
        line('Splendor', top: 0.10, height: 0.08),
        line('Space Cowboys', top: 0.60, height: 0.08),
      ]);
      expect(result, isNot(contains('Splendor Space Cowboys')));
    });

    test('does not merge lines of very different sizes', () {
      final result = extractTitleCandidates([
        line('CATAN', top: 0.10, height: 0.14),
        line('Trade Build Settle', top: 0.26, height: 0.05),
      ]);
      expect(result.first, 'Catan');
      expect(result, isNot(contains('Catan Trade Build Settle')));
    });

    test('drops box boilerplate', () {
      final result = extractTitleCandidates([
        line('Ages 10+', top: 0.8, height: 0.12),
        line('2-4 Players', top: 0.85, height: 0.12),
        line('30-60 min', top: 0.9, height: 0.12),
        line('www.zmangames.com', top: 0.95, height: 0.12),
        line('1234567890', top: 0.5, height: 0.12),
        line('Pandemic', top: 0.2, height: 0.10),
      ]);
      expect(result, ['Pandemic']);
    });

    test('strips trademark symbols and edge punctuation', () {
      final result = extractTitleCandidates([
        line('— Azul™ —', height: 0.12),
      ]);
      expect(result, ['Azul']);
    });

    test('keeps mixed case as-is and title-cases all caps', () {
      expect(extractTitleCandidates([line('King of Tokyo')]), ['King of Tokyo']);
      expect(extractTitleCandidates([line('LORDS OF WATERDEEP')]),
          ['Lords of Waterdeep']);
      expect(extractTitleCandidates([line('CIVILIZATION II')]),
          ['Civilization II']);
    });

    test('returns at most three distinct candidates', () {
      final result = extractTitleCandidates([
        line('Root', top: 0.05, height: 0.12),
        line('ROOT', top: 0.4, height: 0.11),
        line('Leder Games', top: 0.6, height: 0.06),
        line('A Game of Woodland Might', top: 0.7, height: 0.05),
        line('And Right', top: 0.9, height: 0.05),
      ]);
      expect(result.length, lessThanOrEqualTo(3));
      expect(result.first, 'Root');
      expect(result.where((r) => r.toLowerCase() == 'root').length, 1);
    });
  });
}
