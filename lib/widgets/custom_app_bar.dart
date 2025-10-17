import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/auth_service.dart';
import 'package:window_manager/window_manager.dart';

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
    final userRole = user.role;

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
          const SizedBox(height: 2),
          Text(
            '${user.email} (${userRole.toUpperCase()})',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.point_of_sale),
          tooltip: 'Sistem POS',
          onPressed: onGoToPOS,
        ),
        IconButton(
          icon: const Icon(Icons.casino),
          tooltip: 'Biliard Billing',
          onPressed: onGoHome,
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
