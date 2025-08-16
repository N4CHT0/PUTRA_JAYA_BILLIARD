// lib/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:putra_jaya_billiard/pages/home_page.dart';
import 'package:putra_jaya_billiard/pages/login_page.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';

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

        // if (snapshot.hasData) {
        //   return HomePage(user: snapshot.data!);
        // }

        // Jika user belum login
        return const LoginPage();
      },
    );
  }
}
