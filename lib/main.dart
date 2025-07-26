import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart'; // <-- make sure you created this file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyC_ZeekKYRLJssPm4itDrehAhlwBr3imBQ',
      appId:
          '1:491462549728:android:4d0674e71b8c06a680b085', // replace with correct appId
      messagingSenderId: 'bagyotrackr-66ad2',
      projectId: 'bagyotrackr-66ad2',
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BagyoTrackr',
      debugShowCheckedModeBanner: false,
      home: LoginScreen(), // You can change this to SignUpScreen() if needed
    );
  }
}
