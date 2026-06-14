// Entrypoint for the "Anime Pixels" flavor.
//
//   flutter run   --flavor anime -t lib/main_anime.dart --dart-define=FLAVOR=anime
//   flutter build apk --flavor anime -t lib/main_anime.dart --dart-define=FLAVOR=anime
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
