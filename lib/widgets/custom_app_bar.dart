// lib/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';
import 'package:putra_jaya_billiard/widgets/change_password_dialog.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel user;
  final VoidCallback onSettingsChanged;
  final VoidCallback onGoHome;
  final VoidCallback onGoToPOS;
  final VoidCallback onToggleFullscreen;

  const CustomAppBar({
    super.key,
    required this.user,
    required this.onSettingsChanged,
    required this.onGoHome,
    required this.onGoToPOS,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.nama,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            '${user.email} (${user.role.toUpperCase()})',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: 'Toggle Fullscreen',
          onPressed: onToggleFullscreen,
        ),
        IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Dashboard',
          onPressed: onGoHome,
        ),
        // --- TOMBOL BARU ---
        IconButton(
          icon: const Icon(Icons.key),
          tooltip: 'Ganti Password',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const ChangePasswordDialog(),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => authService.signOut(),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
