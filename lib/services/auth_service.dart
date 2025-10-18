// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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

  Future<void> signOut() async {
    try {
      await windowManager.setFullScreen(false);
      await windowManager.setSize(const Size(1024, 650));
      await windowManager.center();
      await _auth.signOut();
    } catch (e) {
      print("Error during sign out: $e");
    }
  }

  // --- FUNGSI BARU ---
  // Fungsi untuk mengganti password
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      return {'success': false, 'message': 'Pengguna tidak ditemukan.'};
    }

    // Buat kredensial untuk re-autentikasi
    AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,
      password: oldPassword,
    );

    try {
      // Langkah 1: Re-autentikasi pengguna untuk keamanan
      await user.reauthenticateWithCredential(credential);

      // Langkah 2: Jika re-autentikasi berhasil, ubah password
      await user.updatePassword(newPassword);

      return {'success': true, 'message': 'Password berhasil diubah!'};
    } on FirebaseAuthException catch (e) {
      // Tangani error umum
      print('Error changing password: ${e.code}');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return {'success': false, 'message': 'Password lama salah.'};
      } else {
        return {'success': false, 'message': 'Terjadi kesalahan: ${e.message}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan tidak dikenal.'};
    }
  }
}
