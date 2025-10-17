// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:putra_jaya_billiard/auth_wrapper.dart';
import 'firebase_options.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // Cukup satu kali ensureInitialized di awal
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await windowManager.ensureInitialized();

  // Atur opsi jendela agar mulai dalam mode normal (tidak fullscreen)
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1024, 650), // Ukuran yang pas untuk jendela login
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    // Tampilkan title bar standar Windows agar jendela bisa digeser
    titleBarStyle: TitleBarStyle.normal,
    fullScreen: false, // <-- PENTING: Diubah menjadi false
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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
