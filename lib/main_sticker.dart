// Entrypoint for the "Sticker Art" flavor.
//
//   flutter run   --flavor sticker -t lib/main_sticker.dart --dart-define=FLAVOR=sticker
//   flutter build apk --flavor sticker -t lib/main_sticker.dart --dart-define=FLAVOR=sticker
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
