// Entrypoint for the "Bible Pixels" Christian-art flavor.
//
//   flutter run   --flavor bible -t lib/main_bible.dart --dart-define=FLAVOR=bible
//   flutter build apk --flavor bible -t lib/main_bible.dart --dart-define=FLAVOR=bible
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
