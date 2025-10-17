import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
// import 'package:putra_jaya_billiard/pages/dashboard/dashboard_page.dart';
import 'package:putra_jaya_billiard/pages/login_page.dart';
import 'package:putra_jaya_billiard/pages/main_layouts.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';
// Import untuk fitur fullscreen
import 'package:window_manager/window_manager.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
          // Jika user terdeteksi, lanjutkan ke RoleDispatcher
          return RoleDispatcher(user: snapshot.data!);
        } else {
          // Jika tidak ada user, tampilkan halaman login
          return const LoginPage();
        }
      },
    );
  }
}

class RoleDispatcher extends StatelessWidget {
  final User user;
  const RoleDispatcher({super.key, required this.user});

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
          // --- LOGIKA FULLSCREEN DITEMPATKAN DI SINI ---
          // Panggil perintah fullscreen setelah UI siap dibangun
          WidgetsBinding.instance.addPostFrameCallback((_) {
            windowManager.setFullScreen(true);
          });
          // --- SELESAI ---

          // Menggunakan factory constructor dari UserModel untuk kode yang lebih bersih
          final userModel = UserModel.fromFirestore(snapshot.data!);

          return MainLayout(user: userModel);
        }

        // Jika data user di Firestore tidak ada (misal dihapus), paksa logout
        // Ini adalah fallback yang aman
        AuthService().signOut();
        return const LoginPage();
      },
    );
  }
}
