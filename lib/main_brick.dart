// Entrypoint for the "Brick Art" flavor.
//
//   flutter run   --flavor brick -t lib/main_brick.dart --dart-define=FLAVOR=brick
//   flutter build apk --flavor brick -t lib/main_brick.dart --dart-define=FLAVOR=brick
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
