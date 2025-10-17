// lib/auth_wrapper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
// import 'package:putra_jaya_billiard/pages/dashboard/dashboard_page.dart';
import 'package:putra_jaya_billiard/pages/login_page.dart';
import 'package:putra_jaya_billiard/pages/main_layouts.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        print(
            "AuthWrapper: Status koneksi stream -> ${snapshot.connectionState}");
        if (snapshot.hasData) {
          print(
              "AuthWrapper: Ditemukan data user di stream, UID -> ${snapshot.data!.uid}");
        } else {
          print(
              "AuthWrapper: Tidak ada data user di stream, menampilkan LoginPage.");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return RoleDispatcher(user: snapshot.data!);
        } else {
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
        print(
            "\nRoleDispatcher: Status koneksi Future -> ${snapshot.connectionState}");
        if (snapshot.connectionState == ConnectionState.done) {
          print("RoleDispatcher: Query Firestore selesai.");
          print(
              "RoleDispatcher: Dokumen ditemukan? -> ${snapshot.data?.exists}");
          if (snapshot.hasError) {
            print(
                "RoleDispatcher: TERJADI ERROR SAAT AMBIL DATA -> ${snapshot.error}");
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          print("RoleDispatcher: Data Firestore -> $data");
          final userModel = UserModel(
            uid: user.uid,
            email: data['email'] ?? 'Email Firestore Kosong',
            role: data['role'] ?? 'pegawai',
            organisasi: data['organisasi'] ?? 'Tidak Diketahui',
            kodeOrganisasi: data['kodeOrganisasi'] ?? 'N/A',
            nama: data['nama'] ?? 'Tanpa Nama',
          );

          return MainLayout(user: userModel);
        }

        print("RoleDispatcher: Dokumen TIDAK DITEMUKAN. Memaksa logout.");
        AuthService().signOut();
        return const LoginPage();
      },
    );
  }
}
