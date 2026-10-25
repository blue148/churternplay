import 'package:churntern_play/features/scanner/retail_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleanRetailTitle', () {
    test('strips UPCItemDB-style listing noise', () {
      expect(
        cleanRetailTitle(
            'Catan Family Strategy Board Game: 5th Edition for Ages 10 and up  from Asmodee'),
        'Catan',
      );
      expect(
        cleanRetailTitle(
            'Pandemic Cooperative Board Game for Ages 8 and up  from Asmodee'),
        'Pandemic',
      );
    });

    test('keeps subtitles that are part of the game name', () {
      expect(cleanRetailTitle('Ticket to Ride: Europe Board Game'),
          'Ticket to Ride: Europe');
      expect(cleanRetailTitle('Pandemic Legacy: Season 1'),
          'Pandemic Legacy: Season 1');
    });

    test('drops bracketed asides, player counts and trademark symbols', () {
      expect(cleanRetailTitle('Wingspan™ (Stonemaier Games) 1-5 Players'),
          'Wingspan');
      expect(cleanRetailTitle('Exploding Kittens Card Game [English Edition]'),
          'Exploding Kittens');
    });

    test('leaves clean names alone', () {
      expect(cleanRetailTitle('Azul'), 'Azul');
      expect(cleanRetailTitle('Lords of Waterdeep'), 'Lords of Waterdeep');
    });

    test('falls back to the original when nothing would remain', () {
      expect(cleanRetailTitle('Board Game'), 'Board Game');
    });
  });
}
