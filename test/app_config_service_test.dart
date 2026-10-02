import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/services/app_config_service.dart';

void main() {
  group('AppConfigService SemVer Comparisons', () {
    test('older versions return true', () {
      expect(AppConfigService.isVersionOlder('1.0.0', '1.0.1'), isTrue);
      expect(AppConfigService.isVersionOlder('1.0.0', '1.1.0'), isTrue);
      expect(AppConfigService.isVersionOlder('1.0.0', '2.0.0'), isTrue);
      expect(AppConfigService.isVersionOlder('1.0.0+1', '1.0.1+2'), isTrue);
      expect(AppConfigService.isVersionOlder('1.9.9', '2.0.0'), isTrue);
    });

    test('equal or newer versions return false', () {
      expect(AppConfigService.isVersionOlder('1.0.0', '1.0.0'), isFalse);
      expect(AppConfigService.isVersionOlder('1.0.1', '1.0.0'), isFalse);
      expect(AppConfigService.isVersionOlder('2.0.0', '1.9.9'), isFalse);
      expect(AppConfigService.isVersionOlder('1.0.0+5', '1.0.0+1'), isFalse);
      expect(AppConfigService.isVersionOlder('1.0.0', ''), isFalse);
    });

    test('handles two-part or partial version strings', () {
      expect(AppConfigService.isVersionOlder('1.0', '1.0.1'), isTrue);
      expect(AppConfigService.isVersionOlder('1.0.1', '1.1'), isTrue);
      expect(AppConfigService.isVersionOlder('2.0', '2.0.0'), isFalse);
    });
  });

  group('AppConfigService Release Notes Parsing', () {
    test('releaseNotesList parses bullet points cleanly', () {
      final service = AppConfigService();
      expect(service.releaseNotesList, isNotEmpty);
      for (final note in service.releaseNotesList) {
        expect(note.startsWith('•'), isFalse);
        expect(note.startsWith('-'), isFalse);
      }
    });

    test('session dismissal behaves as expected', () {
      final service = AppConfigService();
      expect(service.isDismissedThisSession, isFalse);
      service.dismissForSession();
      expect(service.isDismissedThisSession, isTrue);
    });

    test('force update and update availability logic with older/newer versions', () {
      expect(AppConfigService.isVersionOlder('1.0.0', '1.0.1'), isTrue);
      expect(AppConfigService.isVersionOlder('1.0.1', '1.0.0'), isFalse);
      expect(AppConfigService.isVersionOlder('1.0.0', '1.0.0'), isFalse);
    });
  });
}
