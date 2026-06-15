// Entrypoint for the "Gem Art" diamond-painting flavor.
//
//   flutter run   --flavor diamond -t lib/main_diamond.dart --dart-define=FLAVOR=diamond
//   flutter build apk --flavor diamond -t lib/main_diamond.dart --dart-define=FLAVOR=diamond
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
