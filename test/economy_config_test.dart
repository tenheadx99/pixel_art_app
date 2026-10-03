import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/models/economy_config.dart';

void main() {
  test('EconomyConfig parses paywall when map is Map<dynamic, dynamic>', () {
    final Map<String, dynamic> firestoreDoc = {
      'paywall': <dynamic, dynamic>{
        'is_vip_subscription_enabled': false,
        'isVipSubscriptionEnabled': false,
      },
    };

    final config = EconomyConfig.fromMap(firestoreDoc);
    expect(config.paywall.isVipSubscriptionEnabled, isFalse);
  });

  test('EconomyConfig parses is_vip_subscription_enabled at root of doc', () {
    final Map<String, dynamic> firestoreDoc = {
      'is_vip_subscription_enabled': false,
    };

    final config = EconomyConfig.fromMap(firestoreDoc);
    expect(config.paywall.isVipSubscriptionEnabled, isFalse);
  });

  test('EconomyConfig defaults is_vip_subscription_enabled to true if not specified', () {
    final Map<String, dynamic> firestoreDoc = {};

    final config = EconomyConfig.fromMap(firestoreDoc);
    expect(config.paywall.isVipSubscriptionEnabled, isTrue);
  });

  test('EconomyConfig parses isShopEnabled when set to false', () {
    final Map<String, dynamic> firestoreDoc = {
      'isShopEnabled': false,
    };

    final config = EconomyConfig.fromMap(firestoreDoc);
    expect(config.isShopEnabled, isFalse);
  });

  test('EconomyConfig defaults isShopEnabled to true if not specified', () {
    final Map<String, dynamic> firestoreDoc = {};

    final config = EconomyConfig.fromMap(firestoreDoc);
    expect(config.isShopEnabled, isTrue);
  });
}
