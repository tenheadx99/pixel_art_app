// Entrypoint for the "Bead Art" flavor.
//
//   flutter run   --flavor bead -t lib/main_bead.dart --dart-define=FLAVOR=bead
//   flutter build apk --flavor bead -t lib/main_bead.dart --dart-define=FLAVOR=bead
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();

