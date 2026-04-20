// File generated for Firebase project: attnote-staging
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyArQrd7L21L_o_fEK4q7WsmKC2cFjIfFLE',
    appId: '1:714889227250:web:18aaee6ad449015d6c196b',
    messagingSenderId: '714889227250',
    projectId: 'attnote-staging',
    authDomain: 'attnote-staging.firebaseapp.com',
    storageBucket: 'attnote-staging.firebasestorage.app',
    measurementId: 'G-36H19KBX79',
  );
}
