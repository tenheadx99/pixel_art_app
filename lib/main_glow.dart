// Entrypoint for the "Glow Art" flavor.
//
//   flutter run   --flavor glow -t lib/main_glow.dart --dart-define=FLAVOR=glow
//   flutter build apk --flavor glow -t lib/main_glow.dart --dart-define=FLAVOR=glow
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
