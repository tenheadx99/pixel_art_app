// Entrypoint for the "Quilt Art" flavor.
//
//   flutter run   --flavor quilt -t lib/main_quilt.dart --dart-define=FLAVOR=quilt
//   flutter build apk --flavor quilt -t lib/main_quilt.dart --dart-define=FLAVOR=quilt
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
