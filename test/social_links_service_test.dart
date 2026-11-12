import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/data/models/social_link.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/social_links_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SocialLinksService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    service = SocialLinksService();
    service.resetForTesting();
    service.attachStorage(storage);
  });

  tearDown(() {
    service.resetForTesting();
  });

  group('SocialLink & SocialLinksConfig models', () {
    test('SocialLink parses from map correctly', () {
      final map = {
        'id': 'ig_1',
        'platform': 'instagram',
        'title': 'Instagram Page',
        'subtitle': '@pixelyart',
        'url': 'https://instagram.com/pixelyart',
        'colorHex': '#E1306C',
        'isEnabled': true,
        'order': 1,
      };

      final link = SocialLink.fromMap(map);
      expect(link.id, 'ig_1');
      expect(link.platform, 'instagram');
      expect(link.title, 'Instagram Page');
      expect(link.subtitle, '@pixelyart');
      expect(link.url, 'https://instagram.com/pixelyart');
      expect(link.isInstagram, isTrue);
      expect(link.resolvedIcon, Icons.camera_alt_rounded);
      expect(link.resolvedColor, const Color(0xFFE1306C));
      expect(link.isEnabled, isTrue);
      expect(link.order, 1);
    });

    test('SocialLink handles fallback platforms and custom icons', () {
      final link = SocialLink.fromMap({
        'id': 'custom_1',
        'platform': 'custom',
        'title': 'My Website',
        'url': 'https://mywebsite.com',
        'iconKey': 'globe',
        'isEnabled': true,
      });

      expect(link.platform, 'custom');
      expect(link.isInstagram, isFalse);
      expect(link.resolvedIcon, Icons.language_rounded);
      expect(link.resolvedColor, const Color(0xFF706FD3));
    });

    test('SocialLinksConfig serialization and deserialization', () {
      const config = SocialLinksConfig(
        isEnabled: true,
        sectionTitle: 'FOLLOW OUR PAGES',
        links: [
          SocialLink(
            id: 'fb_1',
            platform: 'facebook',
            title: 'Facebook',
            url: 'https://facebook.com/page',
            order: 2,
          ),
          SocialLink(
            id: 'ig_1',
            platform: 'instagram',
            title: 'Instagram',
            url: 'https://instagram.com/page',
            order: 1,
          ),
        ],
      );

      final map = config.toMap();
      final restored = SocialLinksConfig.fromMap(map);

      expect(restored.isEnabled, isTrue);
      expect(restored.sectionTitle, 'FOLLOW OUR PAGES');
      expect(restored.links.length, 2);
      expect(restored.links[0].id, 'fb_1');
      expect(restored.links[1].id, 'ig_1');
    });
  });

  group('SocialLinksService', () {
    test('activeLinks filters disabled links and sorts by order', () {
      service.updateConfigLocally(
        const SocialLinksConfig(
          isEnabled: true,
          sectionTitle: 'COMMUNITY & SOCIAL',
          links: [
            SocialLink(
              id: 'yt',
              platform: 'youtube',
              title: 'YouTube',
              url: 'https://youtube.com',
              order: 3,
              isEnabled: true,
            ),
            SocialLink(
              id: 'fb',
              platform: 'facebook',
              title: 'Facebook',
              url: 'https://facebook.com',
              order: 1,
              isEnabled: true,
            ),
            SocialLink(
              id: 'ig_disabled',
              platform: 'instagram',
              title: 'Instagram Old',
              url: 'https://instagram.com/old',
              order: 0,
              isEnabled: false,
            ),
            SocialLink(
              id: 'empty_url',
              platform: 'x',
              title: 'Twitter',
              url: '   ',
              order: 2,
              isEnabled: true,
            ),
          ],
        ),
      );

      expect(service.activeLinks.length, 2);
      expect(service.activeLinks[0].id, 'fb');
      expect(service.activeLinks[1].id, 'yt');
    });

    test('activeLinks returns empty when master toggle is false', () {
      service.updateConfigLocally(
        const SocialLinksConfig(
          isEnabled: false,
          links: [
            SocialLink(
              id: 'ig',
              platform: 'instagram',
              title: 'Instagram',
              url: 'https://instagram.com',
              isEnabled: true,
            ),
          ],
        ),
      );

      expect(service.activeLinks, isEmpty);
    });

    test('persists to LocalStorage cache and restores on reload', () {
      service.updateConfigLocally(
        const SocialLinksConfig(
          isEnabled: true,
          sectionTitle: 'OUR SOCIALS',
          links: [
            SocialLink(
              id: 'discord_main',
              platform: 'discord',
              title: 'Discord Server',
              subtitle: '5,000 members',
              url: 'https://discord.gg/test',
              isEnabled: true,
              order: 0,
            ),
          ],
        ),
      );

      // Create new service instance reading from the same storage
      final newService = SocialLinksService();
      newService.attachStorage(storage);

      expect(newService.isEnabled, isTrue);
      expect(newService.sectionTitle, 'OUR SOCIALS');
      expect(newService.activeLinks.length, 1);
      expect(newService.activeLinks.first.title, 'Discord Server');
      expect(newService.activeLinks.first.subtitle, '5,000 members');
      expect(newService.activeLinks.first.url, 'https://discord.gg/test');
    });
  });
}

