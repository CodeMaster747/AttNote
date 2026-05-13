// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase options sourced from the project `.env` file.
///
/// Edit `.env` (or copy `.env.example`) to point this app at your own
/// Firebase project — no code changes needed.
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

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _required('FIREBASE_API_KEY'),
        appId: _required('FIREBASE_APP_ID'),
        messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _required('FIREBASE_PROJECT_ID'),
        authDomain: _required('FIREBASE_AUTH_DOMAIN'),
        storageBucket: _required('FIREBASE_STORAGE_BUCKET'),
        measurementId: dotenv.maybeGet('FIREBASE_MEASUREMENT_ID'),
      );

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing $key in .env — copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }
}
