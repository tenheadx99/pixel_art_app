import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/main.dart';

void main() {
  group('isVersionOlder tests', () {
    test('Identical versions should return false', () {
      expect(isVersionOlder('1.0.0', '1.0.0'), isFalse);
    });

    test('Slightly older patch version should return true', () {
      expect(isVersionOlder('1.0.0', '1.0.1'), isTrue);
    });

    test('Older minor version should return true', () {
      expect(isVersionOlder('1.0.5', '1.1.0'), isTrue);
    });

    test('Older major version should return true', () {
      expect(isVersionOlder('1.5.0', '2.0.0'), isTrue);
    });

    test('Newer version should return false', () {
      expect(isVersionOlder('1.1.0', '1.0.5'), isFalse);
      expect(isVersionOlder('2.0.0', '1.9.9'), isFalse);
      expect(isVersionOlder('1.0.10', '1.0.2'), isFalse);
    });

    test('Ignore build metadata suffix and handle correctly', () {
      expect(isVersionOlder('1.0.0+2', '1.0.1'), isTrue);
      expect(isVersionOlder('1.0.1+5', '1.0.1'), isFalse);
    });

    test('Incomplete version formats should handle correctly', () {
      expect(isVersionOlder('1.0', '1.0.1'), isTrue);
      expect(isVersionOlder('1', '2'), isTrue);
      expect(isVersionOlder('2', '1.5'), isFalse);
    });
  });
}
