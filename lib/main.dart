// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:putra_jaya_billiard/auth_wrapper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Putra Jaya Billiard',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Poppins',
            ),
        primaryColor: Colors.tealAccent,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}
