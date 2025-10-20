import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/login_page.dart';
// FIX: Nama file yang benar adalah main_layout.dart bukan main_layouts.dart
import 'package:putra_jaya_billiard/pages/main_layouts.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';
// FIX: Import printer_service.dart
import 'package:putra_jaya_billiard/services/printer_service.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';
import 'package:window_manager/window_manager.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Buat instance untuk kedua service, HANYA SATU KALI.
  final ArduinoService _arduinoService = ArduinoService();
  // FIX: Buat instance untuk PrinterService
  final PrinterService _printerService = PrinterService();

  @override
  void dispose() {
    // Pastikan kedua service di-dispose dengan benar.
    _arduinoService.dispose();
    // FIX: dispose printerService
    _printerService.dispose();
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
          // Teruskan kedua instance service ke RoleDispatcher
          return RoleDispatcher(
            user: snapshot.data!,
            arduinoService: _arduinoService,
            // FIX: Teruskan printerService
            printerService: _printerService,
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
  final ArduinoService arduinoService;
  // FIX: Terima printerService di sini
  final PrinterService printerService;

  const RoleDispatcher({
    super.key,
    required this.user,
    required this.arduinoService,
    // FIX: Jadikan printerService parameter wajib
    required this.printerService,
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

          // Teruskan kedua service ke MainLayout
          return MainLayout(
            user: userModel,
            arduinoService: arduinoService,
            // FIX: Teruskan printerService ke MainLayout
            printerService: printerService,
          );
        }

        AuthService().signOut();
        return const LoginPage();
      },
    );
  }
}
