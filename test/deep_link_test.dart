import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/services/deep_link_service.dart';
import 'package:pixel_art_app/data/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepLinkService Routing Tests', () {
    final service = DeepLinkService.instance;
    final notifications = NotificationService.instance;

    setUp(() {
      notifications.pendingArtworkId.value = null;
      notifications.pendingCategory.value = null;
      notifications.dailyArtRequested.value = false;
      notifications.pendingShopRequested.value = false;
    });

    test('parses query parameter art id from verified HTTPS App Link', () {
      final uri = Uri.parse('https://om108-5c015.web.app/art?id=shiva_01&flavor=devotional');
      service.handleUri(uri);

      expect(notifications.pendingArtworkId.value, 'shiva_01');
    });

    test('parses path-based artwork id', () {
      final uri = Uri.parse('https://om108-5c015.web.app/art/ganesha_02');
      service.handleUri(uri);

      expect(notifications.pendingArtworkId.value, 'ganesha_02');
    });

    test('parses custom scheme pixely://art?id=xxx', () {
      final uri = Uri.parse('pixely://art?id=krishna_03');
      service.handleUri(uri);

      expect(notifications.pendingArtworkId.value, 'krishna_03');
    });

    test('parses daily art deep link', () {
      final uri = Uri.parse('https://om108-5c015.web.app/daily');
      service.handleUri(uri);

      expect(notifications.dailyArtRequested.value, isTrue);
    });

    test('parses category deep link', () {
      final uri = Uri.parse('https://om108-5c015.web.app/art?category=Gods');
      service.handleUri(uri);

      expect(notifications.pendingCategory.value, 'Gods');
    });

    test('parses shop deep link', () {
      final uri = Uri.parse('https://om108-5c015.web.app/shop');
      service.handleUri(uri);

      expect(notifications.pendingShopRequested.value, isTrue);
    });
  });
}
