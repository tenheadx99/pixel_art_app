// Entrypoint for the "Mosaic Art" flavor.
//
//   flutter run   --flavor mosaic -t lib/main_mosaic.dart --dart-define=FLAVOR=mosaic
//   flutter build apk --flavor mosaic -t lib/main_mosaic.dart --dart-define=FLAVOR=mosaic
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
