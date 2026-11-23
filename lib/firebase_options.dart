import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDqjvRJZuuX4OnYUfPh4N2rsqG5nRddRl4',
    appId: '1:289083230009:web:9ac03a30070505cf524ae8',
    messagingSenderId: '289083230009',
    projectId: 'elora-school',
    authDomain: 'elora-school.firebaseapp.com',
    storageBucket: 'elora-school.firebasestorage.app',
    measurementId: 'G-22QGNSRLPZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAX_pbGD-pu0g5Y3fkG4NvuH4tbkpHAWC4',
    appId: '1:289083230009:android:6ea8f904570c173e524ae8',
    messagingSenderId: '289083230009',
    projectId: 'elora-school',
    storageBucket: 'elora-school.firebasestorage.app',
  );
}
