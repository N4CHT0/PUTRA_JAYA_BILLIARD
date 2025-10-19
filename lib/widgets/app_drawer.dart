// lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';

class AppDrawer extends StatelessWidget {
  final UserModel user;
  final Function(int) onPageSelected;

  const AppDrawer({
    super.key,
    required this.user,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    void handleNavigation(int index) {
      onPageSelected(index);
      Navigator.pop(context);
    }

    return Drawer(
      child: Container(
        color: const Color(0xFF16213e),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName:
                  Text(user.nama, style: const TextStyle(fontSize: 18)),
              accountEmail: Text(user.email),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1a1a2e),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text('Dashboard'),
              onTap: () => handleNavigation(0),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale_rounded),
              title: const Text('Point of Sale (POS)'),
              onTap: () => handleNavigation(6),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_rounded),
              title: const Text('Transaksi Pembelian'),
              onTap: () => handleNavigation(8),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('Laporan Keuangan'),
              onTap: () => handleNavigation(1),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_rounded),
              title: const Text('Laporan Stok'),
              onTap: () => handleNavigation(9),
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: const Text('Kartu Stok'),
              onTap: () => handleNavigation(11),
            ),
            if (user.role == 'admin') ...[
              const Divider(color: Colors.white24, indent: 16, endIndent: 16),
              const Padding(
                padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                child:
                    Text('Admin Menu', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts_rounded),
                title: const Text('Manajemen Akun'),
                onTap: () => handleNavigation(2),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('Riwayat Arus Kas'),
                onTap: () => handleNavigation(3),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_rounded),
                title: const Text('Manajemen Produk'),
                onTap: () => handleNavigation(5),
              ),
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('Manajemen Supplier'),
                onTap: () => handleNavigation(7),
              ),
              ListTile(
                leading: const Icon(Icons.card_membership_rounded),
                title: const Text('Manajemen Member'),
                onTap: () => handleNavigation(12),
              ),
              ListTile(
                leading: const Icon(Icons.rule_folder_rounded),
                title: const Text('Stok Opname'),
                onTap: () => handleNavigation(10),
              ),
              ListTile(
                leading: const Icon(Icons.price_change_rounded),
                title: const Text('Price Settings'),
                onTap: () => handleNavigation(4),
              ),
              ListTile(
                leading: const Icon(Icons.payment_rounded),
                title: const Text('Metode Pembayaran'),
                onTap: () => handleNavigation(14),
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('General Settings'),
                onTap: () => handleNavigation(13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
