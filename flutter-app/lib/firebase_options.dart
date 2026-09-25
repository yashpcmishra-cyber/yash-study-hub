// Auto-generated-style file using YOUR real Firebase project values.
// (Normally the FlutterFire CLI generates this file for you, but since
// those values are already known, they're filled in directly here.)
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDSAvRzTNcXVENKNSUe0LqwuHLNZHRtHh0',
    appId: '1:782647828219:web:bd86accdd0eeffed165a5e',
    messagingSenderId: '782647828219',
    projectId: 'yash-study-hub-450d2',
    authDomain: 'yash-study-hub-450d2.firebaseapp.com',
    storageBucket: 'yash-study-hub-450d2.firebasestorage.app',
    measurementId: 'G-8TW7WN1V95',
  );

  // Android app registered ✅ (package: com.yashstudyhub.app) — real appId below.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSAvRzTNcXVENKNSUe0LqwuHLNZHRtHh0',
    appId: '1:782647828219:android:f46c55bd6c5b9a9e165a5e',
    messagingSenderId: '782647828219',
    projectId: 'yash-study-hub-450d2',
    storageBucket: 'yash-study-hub-450d2.firebasestorage.app',
  );

  // iOS app NOT registered yet — only needed if you ever build for iPhone.
  // Same steps as Android (Project Settings > Add app > iOS) if/when needed.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDSAvRzTNcXVENKNSUe0LqwuHLNZHRtHh0',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '782647828219',
    projectId: 'yash-study-hub-450d2',
    storageBucket: 'yash-study-hub-450d2.firebasestorage.app',
    iosBundleId: 'com.yashstudyhub.app',
  );
}
