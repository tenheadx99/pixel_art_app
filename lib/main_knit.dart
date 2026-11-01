// Entrypoint for the "Knit Art" flavor.
//
//   flutter run   --flavor knit -t lib/main_knit.dart --dart-define=FLAVOR=knit
//   flutter build apk --flavor knit -t lib/main_knit.dart --dart-define=FLAVOR=knit
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
