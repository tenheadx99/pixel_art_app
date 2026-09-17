import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_catalog_service.dart';

PixelArt makeArt(String id, {int size = 2, int partsX = 1, int partsY = 1}) {
  return PixelArt(
    id: id,
    name: id,
    gridWidth: size,
    gridHeight: size,
    grid: List.generate(size, (_) => List.filled(size, 1)),
    colorMap: {1: const Color(0xFF000000)},
    category: 'General',
    partsX: partsX,
    partsY: partsY,
  );
}

/// A replacement doc as the admin panel publishes it.
Map<String, dynamic> docFor(
  PixelArt a, {
  String? replaces,
  bool visible = true,
  String? availableFrom,
  String? minAppVersion,
}) =>
    {
      ...a.toJson(),
      'visible': visible,
      'replaces': ?replaces,
      'availableFrom': ?availableFrom,
      'minAppVersion': ?minAppVersion,
    };

Future<(RemoteCatalogService, LocalStorageService)> serviceWith(
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = LocalStorageService();
  await storage.init();
  return (RemoteCatalogService(storage), storage);
}

/// The full progress key family ColoringProvider persists for one artwork.
Map<String, Object> progressFamily(String id) => {
      'pixelart_progress_$id': '1,0;0,1',
      'pixelart_progress_${id}_pct': 60,
      'pixelart_progress_${id}_ts': 1234,
      'pixelart_progress_${id}_fills': 9,
      'pixelart_progress_${id}_erases': 2,
      'pixelart_progress_${id}_timelapse': '0,0;1,1',
      'pixelart_progress_${id}_milestones': '30',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldId = 'bird_01';
  const newId = 'rmt_bird_01_1712345678901';
  final bundled = [makeArt(oldId), makeArt('cat_01')];
  final hiddenOld = {
    oldId: <String, dynamic>{'hidden': true},
  };

  group('applyReplacementHandOffs', () {
    test('copies the full progress family and memberships once', () async {
      final (svc, storage) = await serviceWith({
        ...progressFamily(oldId),
        'completed_ids': <String>[oldId],
        'favorite_ids': <String>[oldId],
        'diamond_unlocked_ids': <String>[oldId],
        'diamonds_awarded_$oldId': true,
      });

      final handedOff = svc.applyReplacementHandOffs(
        bundled,
        [docFor(makeArt(newId))],
        hiddenOld,
      );

      expect(handedOff, {oldId});
      expect(storage.getString('pixelart_progress_$newId'), '1,0;0,1');
      expect(storage.getInt('pixelart_progress_${newId}_pct'), 60);
      expect(storage.getInt('pixelart_progress_${newId}_ts'), 1234);
      expect(storage.getInt('pixelart_progress_${newId}_fills'), 9);
      expect(storage.getInt('pixelart_progress_${newId}_erases'), 2);
      expect(storage.getString('pixelart_progress_${newId}_timelapse'),
          '0,0;1,1');
      expect(
          storage.getString('pixelart_progress_${newId}_milestones'), '30');
      // Memberships are copied, never moved: the bundled art must keep
      // working offline.
      expect(storage.getStringSet('completed_ids'), containsAll([oldId, newId]));
      expect(storage.getStringSet('favorite_ids'), containsAll([oldId, newId]));
      expect(storage.getStringSet('diamond_unlocked_ids'),
          containsAll([oldId, newId]));
      expect(storage.getBool('diamonds_awarded_$newId'), isTrue);
      expect(storage.getBool('progress_handoff_done_$newId'), isTrue);
      // Old family untouched.
      expect(storage.getString('pixelart_progress_$oldId'), '1,0;0,1');
      expect(storage.getInt('pixelart_progress_${oldId}_pct'), 60);
    });

    test('does not clobber progress the user already has on the replacement',
        () async {
      final (svc, storage) = await serviceWith({
        ...progressFamily(oldId),
        'pixelart_progress_$newId': '0,1;1,0',
        'pixelart_progress_${newId}_pct': 25,
      });

      svc.applyReplacementHandOffs(bundled, [docFor(makeArt(newId))], hiddenOld);

      expect(storage.getString('pixelart_progress_$newId'), '0,1;1,0');
      expect(storage.getInt('pixelart_progress_${newId}_pct'), 25);
    });

    test('the one-shot marker prevents a second copy', () async {
      final (svc, storage) = await serviceWith({
        ...progressFamily(oldId),
        'progress_handoff_done_$newId': true,
      });

      final handedOff = svc.applyReplacementHandOffs(
        bundled,
        [docFor(makeArt(newId))],
        hiddenOld,
      );

      // Still reported as handed off (no retention needed), but no copy ran.
      expect(handedOff, {oldId});
      expect(storage.getString('pixelart_progress_$newId'), isEmpty);
    });

    test('a grid-dimension mismatch skips the hand-off entirely', () async {
      final (svc, storage) = await serviceWith(progressFamily(oldId));

      final handedOff = svc.applyReplacementHandOffs(
        bundled,
        [docFor(makeArt(newId, size: 3))],
        hiddenOld,
      );

      expect(handedOff, isEmpty);
      expect(storage.getString('pixelart_progress_$newId'), isEmpty);
    });

    test('requires the original to be hidden (slug-collision guard)',
        () async {
      final (svc, storage) = await serviceWith(progressFamily(oldId));

      final handedOff = svc.applyReplacementHandOffs(
        bundled,
        [docFor(makeArt(newId))],
        {},
      );

      expect(handedOff, isEmpty);
      expect(storage.getString('pixelart_progress_$newId'), isEmpty);
    });

    test('an explicit replaces field works for unparseable ids', () async {
      const customId = 'rmt_totally_renamed';
      final (svc, storage) = await serviceWith(progressFamily(oldId));

      final handedOff = svc.applyReplacementHandOffs(
        bundled,
        [docFor(makeArt(customId), replaces: oldId)],
        hiddenOld,
      );

      expect(handedOff, {oldId});
      expect(storage.getString('pixelart_progress_$customId'), '1,0;0,1');
    });

    test('split artworks hand off every part key family', () async {
      const oldSplit = 'temple_01';
      const newSplit = 'rmt_temple_01_99';
      final (svc, storage) = await serviceWith({
        ...progressFamily('${oldSplit}_p0'),
        ...progressFamily('${oldSplit}_p1'),
        'completed_ids': <String>['${oldSplit}_p0'],
      });

      final handedOff = svc.applyReplacementHandOffs(
        [makeArt(oldSplit, partsX: 2)],
        [docFor(makeArt(newSplit, partsX: 2))],
        {
          oldSplit: <String, dynamic>{'hidden': true},
        },
      );

      expect(handedOff, {oldSplit});
      expect(storage.getString('pixelart_progress_${newSplit}_p0'), '1,0;0,1');
      expect(storage.getInt('pixelart_progress_${newSplit}_p1_pct'), 60);
      expect(storage.getStringSet('completed_ids'),
          containsAll(['${oldSplit}_p0', '${newSplit}_p0']));
    });

    test('a replacement this build cannot see does not count as handed off',
        () async {
      // If the replacement is filtered out of the merged catalog (draft,
      // future-scheduled, or version-gated), handing off would suppress
      // retention of the hidden original while the replacement is absent too
      // — the artwork and its progress would vanish. All three gates must
      // block the hand-off.
      final (svc, storage) = await serviceWith(progressFamily(oldId));

      for (final doc in [
        docFor(makeArt(newId), visible: false),
        docFor(makeArt(newId), availableFrom: '2999-01-01T00:00:00.000'),
        docFor(makeArt(newId), minAppVersion: '9.9.9'),
      ]) {
        final handedOff = svc.applyReplacementHandOffs(
          bundled,
          [doc],
          hiddenOld,
          currentAppVersion: '1.0.12',
        );
        expect(handedOff, isEmpty);
        expect(storage.getString('pixelart_progress_$newId'), isEmpty);
      }
    });

    test('the done marker alone reports handed off on later launches',
        () async {
      // After the copy, later launches must not need the full-grid parse —
      // but the id still counts as handed off so the original isn't retained
      // alongside its replacement.
      final (svc, _) = await serviceWith({
        'progress_handoff_done_$newId': true,
      });

      final handedOff = svc.applyReplacementHandOffs(
        bundled,
        [docFor(makeArt(newId))],
        hiddenOld,
      );
      expect(handedOff, {oldId});
    });

    test('untouched split parts copy nothing (write-storm guard)', () async {
      const oldSplit = 'temple_01';
      const newSplit = 'rmt_temple_01_99';
      // Only p0 has progress; p1 is untouched.
      final (svc, storage) = await serviceWith(
        progressFamily('${oldSplit}_p0'),
      );

      svc.applyReplacementHandOffs(
        [makeArt(oldSplit, partsX: 2)],
        [docFor(makeArt(newSplit, partsX: 2))],
        {
          oldSplit: <String, dynamic>{'hidden': true},
        },
      );

      expect(storage.getString('pixelart_progress_${newSplit}_p0'), '1,0;0,1');
      // The empty p1 family must not have been written at all.
      expect(
        storage.prefs.containsKey('pixelart_progress_${newSplit}_p1'),
        isFalse,
      );
      expect(
        storage.prefs.containsKey('pixelart_progress_${newSplit}_p1_pct'),
        isFalse,
      );
    });

    test('a part-layout mismatch skips the hand-off', () async {
      const oldSplit = 'temple_01';
      const newSplit = 'rmt_temple_01_99';
      final (svc, storage) = await serviceWith(
        progressFamily('${oldSplit}_p0'),
      );

      final handedOff = svc.applyReplacementHandOffs(
        [makeArt(oldSplit, partsX: 2)],
        [docFor(makeArt(newSplit, partsX: 1))],
        {
          oldSplit: <String, dynamic>{'hidden': true},
        },
      );

      expect(handedOff, isEmpty);
      expect(storage.getString('pixelart_progress_${newSplit}_p0'), isEmpty);
    });
  });
}
