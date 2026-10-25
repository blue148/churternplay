import 'package:churntern_play/data/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('displayableAvatarUrl', () {
    test('swaps DiceBear SVG avatars for PNG', () {
      expect(
        displayableAvatarUrl(
            'https://api.dicebear.com/7.x/avataaars/svg?seed=Oliver'),
        'https://api.dicebear.com/7.x/avataaars/png?seed=Oliver',
      );
    });

    test('leaves other URLs and null alone', () {
      const uploaded =
          'https://example.supabase.co/storage/v1/object/public/avatars/u/a.svg';
      expect(displayableAvatarUrl(uploaded), uploaded);
      expect(
        displayableAvatarUrl(
            'https://api.dicebear.com/7.x/avataaars/png?seed=Max'),
        'https://api.dicebear.com/7.x/avataaars/png?seed=Max',
      );
      expect(displayableAvatarUrl(null), isNull);
    });
  });
}
