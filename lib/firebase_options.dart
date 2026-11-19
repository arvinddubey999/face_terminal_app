// File generated for Firebase initialization matching google-services.json
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
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAL_9Hc29v_Rh2NneTkUllSv88i3ASPtmk',
    appId: '1:246334008034:android:27be52d6604720a068ccbb',
    messagingSenderId: '246334008034',
    projectId: 'hrms-2563e',
    storageBucket: 'hrms-2563e.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAL_9Hc29v_Rh2NneTkUllSv88i3ASPtmk',
    appId: '1:246334008034:web:0000000000000000000000',
    messagingSenderId: '246334008034',
    projectId: 'hrms-2563e',
    storageBucket: 'hrms-2563e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAL_9Hc29v_Rh2NneTkUllSv88i3ASPtmk',
    appId: '1:246334008034:ios:0000000000000000000000',
    messagingSenderId: '246334008034',
    projectId: 'hrms-2563e',
    storageBucket: 'hrms-2563e.firebasestorage.app',
  );
}
