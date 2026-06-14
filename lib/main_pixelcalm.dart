// Entrypoint for the "PixelCalm" mindfulness flavor.
//
//   flutter run   --flavor pixelcalm -t lib/main_pixelcalm.dart --dart-define=FLAVOR=pixelcalm
//   flutter build apk --flavor pixelcalm -t lib/main_pixelcalm.dart --dart-define=FLAVOR=pixelcalm
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
