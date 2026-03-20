import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for android - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABSKMDY7eo8ZVFFai4fvF8DRveIFOeEt4',
    appId: '1:964869146856:web:83ff4599cf5cada401e15d',
    messagingSenderId: '964869146856',
    projectId: 'math-quiz-app-893b2',
    authDomain: 'math-quiz-app-893b2.firebaseapp.com',
    databaseURL: 'https://math-quiz-app-893b2-default-rtdb.firebaseio.com',
    storageBucket: 'math-quiz-app-893b2.firebasestorage.app',
    measurementId: 'G-DJK6P5ZQS8',
  );

}