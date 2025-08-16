// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream untuk memantau perubahan status autentikasi (login/logout)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Fungsi untuk login dengan email dan password
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Menampilkan pesan error yang lebih spesifik
      print('Error Login: ${e.message}');
      return null;
    }
  }

  /// Fungsi untuk logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
