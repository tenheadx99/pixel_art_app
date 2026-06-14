// Entrypoint for the "Divine Pixels" devotional flavor.
//
// Run / build with the matching flavor + dart-define so the app id, icon and
// curated deity catalog are selected:
//
//   flutter run   --flavor devotional -t lib/main_devotional.dart --dart-define=FLAVOR=devotional
//   flutter build apk --flavor devotional -t lib/main_devotional.dart --dart-define=FLAVOR=devotional
//
// The actual flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
