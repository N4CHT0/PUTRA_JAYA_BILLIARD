// file: lib/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';

// Gunakan 'implements PreferredSizeWidget' agar bisa dipakai di Scaffold.appBar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel user;
  final VoidCallback onSettingsChanged;
  final VoidCallback onGoHome; // Definisikan parameter di sini

  const CustomAppBar({
    super.key,
    required this.user,
    required this.onSettingsChanged,
    required this.onGoHome, // Tambahkan ke constructor
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userRole = user.role;

    return AppBar(
      backgroundColor:
          Colors.transparent, // Transparan agar gradasi body terlihat
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.nama,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '${user.email} (${userRole.toUpperCase()})',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.point_of_sale), // Ikon mesin kasir
          tooltip: 'Sistem POS',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Halaman POS belum diimplementasikan.')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.home), // Ikon Beranda
          tooltip: 'Dashboard',
          onPressed: onGoHome, // Gunakan parameter di sini
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => authService.signOut(),
        ),
      ],
    );
  }

  // Tentukan tinggi AppBar
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
