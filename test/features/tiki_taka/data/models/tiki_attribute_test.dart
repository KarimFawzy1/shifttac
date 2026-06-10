import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';

void main() {
  group('TikiAttribute.boardHeaderLabel', () {
    test('uses short codes for position attributes', () {
      expect(
        const TikiAttribute(
          id: 'pos:GK',
          type: 'position',
          displayName: 'Goalkeeper',
          slug: 'goalkeeper',
          iconKey: 'pos_gk',
        ).boardHeaderLabel,
        'GK',
      );
      expect(
        const TikiAttribute(
          id: 'pos:DEF',
          type: 'position',
          displayName: 'Defender',
          slug: 'defender',
          iconKey: 'pos_def',
        ).boardHeaderLabel,
        'DEF',
      );
      expect(
        const TikiAttribute(
          id: 'pos:MID',
          type: 'position',
          displayName: 'Midfielder',
          slug: 'midfielder',
          iconKey: 'pos_mid',
        ).boardHeaderLabel,
        'MID',
      );
      expect(
        const TikiAttribute(
          id: 'pos:FWD',
          type: 'position',
          displayName: 'Forward',
          slug: 'forward',
          iconKey: 'pos_fwd',
        ).boardHeaderLabel,
        'FWD',
      );
    });

    test('keeps full display name for non-position attributes', () {
      expect(
        const TikiAttribute(
          id: 'club:31',
          type: 'club',
          displayName: 'Liverpool',
          slug: 'liverpool',
          iconKey: 'club_31',
        ).boardHeaderLabel,
        'Liverpool',
      );
    });
  });
}
