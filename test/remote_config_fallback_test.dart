import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/config/flavor.dart';

void main() {
  group('Remote Config flavor key mapping', () {
    test('resolves correct keys for original flavor', () {
      expect(
        FlavorConfig.getFlavorKey(AppFlavor.original, 'show_ads'),
        'pixelyart_show_ads',
      );
      expect(
        FlavorConfig.getFlavorKey(AppFlavor.original, 'banner_ad_unit_id'),
        'pixelyart_banner_ad_unit_id',
      );
    });

    test('resolves correct keys for devotional flavor', () {
      expect(
        FlavorConfig.getFlavorKey(AppFlavor.devotional, 'show_ads'),
        'devotional_show_ads',
      );
    });

    test('resolves correct keys for anime flavor', () {
      expect(
        FlavorConfig.getFlavorKey(AppFlavor.anime, 'show_ads'),
        'anime_show_ads',
      );
    });

    test('resolves correct keys for pixelcalm flavor', () {
      expect(
        FlavorConfig.getFlavorKey(AppFlavor.pixelcalm, 'show_ads'),
        'pixelcalm_show_ads',
      );
    });

    test('resolves correct keys for diamond flavor', () {
      expect(
        FlavorConfig.getFlavorKey(AppFlavor.diamond, 'show_ads'),
        'diamond_show_ads',
      );
    });
  });
}
