// Entrypoint for the "Voxel Art" flavor.
//
//   flutter run   --flavor voxel -t lib/main_voxel.dart --dart-define=FLAVOR=voxel
//   flutter build apk --flavor voxel -t lib/main_voxel.dart --dart-define=FLAVOR=voxel
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
