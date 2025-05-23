// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC67IATmJxlP959YHVK6M0TLybXCRxWSyg',
    appId: '1:130840150982:web:4673c65b7a64c372e2a8c7',
    messagingSenderId: '130840150982',
    projectId: 'newscalendar-ac03a',
    authDomain: 'newscalendar-ac03a.firebaseapp.com',
    storageBucket: 'newscalendar-ac03a.firebasestorage.app',
    measurementId: 'G-SLWHJLKPG2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBPOnqGSSfIY21te1v2kwJdYgV8bJ_yVOI',
    appId: '1:130840150982:android:6eab0d3f2a77817ee2a8c7',
    messagingSenderId: '130840150982',
    projectId: 'newscalendar-ac03a',
    storageBucket: 'newscalendar-ac03a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJEotsN293nnmTW1exZAl1Z_goBFIFhYY',
    appId: '1:130840150982:ios:f747a8e343395c7fe2a8c7',
    messagingSenderId: '130840150982',
    projectId: 'newscalendar-ac03a',
    storageBucket: 'newscalendar-ac03a.firebasestorage.app',
    iosBundleId: 'com.example.newscalendar',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAJEotsN293nnmTW1exZAl1Z_goBFIFhYY',
    appId: '1:130840150982:ios:f747a8e343395c7fe2a8c7',
    messagingSenderId: '130840150982',
    projectId: 'newscalendar-ac03a',
    storageBucket: 'newscalendar-ac03a.firebasestorage.app',
    iosBundleId: 'com.example.newscalendar',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC67IATmJxlP959YHVK6M0TLybXCRxWSyg',
    appId: '1:130840150982:web:4063ea88f5d5cacde2a8c7',
    messagingSenderId: '130840150982',
    projectId: 'newscalendar-ac03a',
    authDomain: 'newscalendar-ac03a.firebaseapp.com',
    storageBucket: 'newscalendar-ac03a.firebasestorage.app',
    measurementId: 'G-JLHJ858PQP',
  );
}
