// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // <-- Butuh untuk Size
import 'package:window_manager/window_manager.dart'; // <-- 1. IMPORT PACKAGE

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Error Login: ${e.message}');
      return null;
    }
  }

  /// Fungsi untuk logout
  Future<void> signOut() async {
    try {
      // --- 2. LOGIKA KELUAR FULLSCREEN DITEMPATKAN DI SINI ---
      // Keluar dari mode fullscreen terlebih dahulu
      await windowManager.setFullScreen(false);
      // Opsional: Kembalikan ukuran jendela ke ukuran login
      await windowManager.setSize(const Size(1024, 650));
      await windowManager.center();
      // --- SELESAI ---

      // Setelah jendela kembali normal, baru proses logout Firebase
      await _auth.signOut();
    } catch (e) {
      print("Error during sign out: $e");
    }
  }
}
