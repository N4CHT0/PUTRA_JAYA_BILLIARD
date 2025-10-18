import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/login_page.dart';
import 'package:putra_jaya_billiard/pages/main_layouts.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart'; // Import service
import 'package:putra_jaya_billiard/services/auth_service.dart';
import 'package:window_manager/window_manager.dart';

// DIUBAH MENJADI STATEFULWIDGET
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // 1. Buat instance ArduinoService di sini, HANYA SATU KALI.
  final ArduinoService _arduinoService = ArduinoService();

  @override
  void dispose() {
    // 2. Pastikan service di-dispose dengan benar saat aplikasi ditutup.
    _arduinoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // 3. Teruskan instance service ke RoleDispatcher
          return RoleDispatcher(
            user: snapshot.data!,
            arduinoService: _arduinoService,
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class RoleDispatcher extends StatelessWidget {
  final User user;
  final ArduinoService arduinoService; // 4. Terima service di sini

  const RoleDispatcher({
    super.key,
    required this.user,
    required this.arduinoService, // 5. Jadikan parameter wajib
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            windowManager.setFullScreen(true);
          });

          final userModel = UserModel.fromFirestore(snapshot.data!);

          // 6. Teruskan service ke MainLayout, error sekarang teratasi!
          return MainLayout(
            user: userModel,
            arduinoService: arduinoService,
          );
        }

        AuthService().signOut();
        return const LoginPage();
      },
    );
  }
}
