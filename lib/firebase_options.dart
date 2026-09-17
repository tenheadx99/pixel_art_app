// File: lib/firebase_options.dart
// Generated to support multi-flavor Firebase configurations.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'config/flavor.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidOptions;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static FirebaseOptions get androidOptions {
    final flavor = currentFlavor;
    switch (flavor) {
      case AppFlavor.original:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDLdv_gx0rgVEiJ5i4ufkFb7h1cSLe8vtE',
          appId: '1:433057017992:android:f9a922b4c41a0a2255af3d',
          messagingSenderId: '433057017992',
          projectId: 'om108-5c015',
          storageBucket: 'om108-5c015.firebasestorage.app',
        );
            case AppFlavor.devotional:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDLdv_gx0rgVEiJ5i4ufkFb7h1cSLe8vtE',
          appId: '1:433057017992:android:d1f8d47bd6532e9055af3d',
          messagingSenderId: '433057017992',
          projectId: 'om108-5c015',
          storageBucket: 'om108-5c015.firebasestorage.app',
        );
      case AppFlavor.anime:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDLdv_gx0rgVEiJ5i4ufkFb7h1cSLe8vtE',
          appId: '1:433057017992:android:0cf03c30178aa10f55af3d',
          messagingSenderId: '433057017992',
          projectId: 'om108-5c015',
          storageBucket: 'om108-5c015.firebasestorage.app',
        );
      case AppFlavor.pixelcalm:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDLdv_gx0rgVEiJ5i4ufkFb7h1cSLe8vtE',
          appId: '1:433057017992:android:1d0938add0b865f655af3d',
          messagingSenderId: '433057017992',
          projectId: 'om108-5c015',
          storageBucket: 'om108-5c015.firebasestorage.app',
        );
      case AppFlavor.diamond:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDLdv_gx0rgVEiJ5i4ufkFb7h1cSLe8vtE',
          appId: '1:433057017992:android:d86e17566a857d9f55af3d',
          messagingSenderId: '433057017992',
          projectId: 'om108-5c015',
          storageBucket: 'om108-5c015.firebasestorage.app',
        );
      case AppFlavor.bible:
        // TODO: replace appId after registering com.tenhead.biblepixels in
        // the Firebase console (using the original app's id until then).
        return const FirebaseOptions(
          apiKey: 'AIzaSyDLdv_gx0rgVEiJ5i4ufkFb7h1cSLe8vtE',
          appId: '1:433057017992:android:f9a922b4c41a0a2255af3d',
          messagingSenderId: '433057017992',
          projectId: 'om108-5c015',
          storageBucket: 'om108-5c015.firebasestorage.app',
        );
    }
  }
}
