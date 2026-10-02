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

    test('it should hide on click of update button', () {
      final service = AppConfigService();
      service.resetStateForTesting();
      service.setCurrentAppVersionForTesting('1.0.0');
      service.setTargetVersionForTesting('1.0.1');

      // Before clicking update, update card should show
      expect(service.isUpdateAvailable, isTrue);
      expect(service.shouldShowUpdateCard, isTrue);

      // User clicks on update button
      service.dismissForSession();

      // It should hide on click of update button
      expect(service.isDismissedThisSession, isTrue);
      expect(service.shouldShowUpdateCard, isFalse);
    });

    test('it should hide if app version gets updated', () {
      final service = AppConfigService();
      service.resetStateForTesting();
      service.setTargetVersionForTesting('2.0.0');

      // Initially on older version
      service.setCurrentAppVersionForTesting('1.0.0');
      expect(service.isUpdateAvailable, isTrue);
      expect(service.shouldShowUpdateCard, isTrue);

      // App version gets updated to 2.0.0
      service.setCurrentAppVersionForTesting('2.0.0');

      // It should hide because app version is updated
      expect(service.isUpdateAvailable, isFalse);
      expect(service.shouldShowUpdateCard, isFalse);

      // Even if app is updated beyond target (e.g. 2.0.1)
      service.setCurrentAppVersionForTesting('2.0.1');
      expect(service.isUpdateAvailable, isFalse);
      expect(service.shouldShowUpdateCard, isFalse);
    });

    test('if app version is not updated it should be shown', () {
      final service = AppConfigService();
      service.resetStateForTesting();
      service.setCurrentAppVersionForTesting('1.0.0');
      service.setTargetVersionForTesting('2.0.0');

      // User clicked update in a previous session
      service.dismissForSession();
      expect(service.shouldShowUpdateCard, isFalse);

      // In a subsequent session/launch, app version is STILL NOT updated (1.0.0 < 2.0.0)
      service.resetStateForTesting();

      // If app version is not updated it should be shown
      expect(service.isUpdateAvailable, isTrue);
      expect(service.isDismissedThisSession, isFalse);
      expect(service.shouldShowUpdateCard, isTrue);
    });

    test('future newer update can still show after previous update was completed', () {
      final service = AppConfigService();
      service.resetStateForTesting();

      // App updated to 2.0.0
      service.setCurrentAppVersionForTesting('2.0.0');
      service.setTargetVersionForTesting('2.0.0');
      expect(service.shouldShowUpdateCard, isFalse);

      // Now developer releases 2.1.0 in the future
      service.setTargetVersionForTesting('2.1.0');
      expect(service.isUpdateAvailable, isTrue);
      expect(service.shouldShowUpdateCard, isTrue);
    });
  });
}
