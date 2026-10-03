// Entrypoint for the "Cross Stitch" flavor.
//
//   flutter run   --flavor crossStitch -t lib/main_cross_stitch.dart --dart-define=FLAVOR=stitch
//   flutter build apk --flavor crossStitch -t lib/main_cross_stitch.dart --dart-define=FLAVOR=stitch
//
// The active flavor is resolved from the FLAVOR dart-define (see
// lib/config/flavor.dart); this file only provides a distinct build target.
import 'main.dart' as app;

Future<void> main() => app.bootstrapApp();
