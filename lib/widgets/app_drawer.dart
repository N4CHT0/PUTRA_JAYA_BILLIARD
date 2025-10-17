import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';

class AppDrawer extends StatelessWidget {
  final UserModel user;
  final Function(int)
      onPageSelected; // Callback untuk memberitahu halaman mana yang dipilih

  const AppDrawer({
    super.key,
    required this.user,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
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
              onTap: () {
                onPageSelected(0); // Index 0 untuk Dashboard
                Navigator.pop(context); // Tutup drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale_rounded),
              title: const Text('Point of Sale (POS)'),
              onTap: () {
                // Arahkan ke halaman POS
                onPageSelected(6); // <-- Ganti ke indeks baru (6)
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('Laporan Pendapatan'),
              onTap: () {
                onPageSelected(1); // Index 1 untuk Laporan
                Navigator.pop(context);
              },
            ),
            // Tampilkan menu khusus jika role pengguna adalah 'admin'
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
                onTap: () {
                  onPageSelected(2); // Index 2 untuk Akun
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('Riwayat Transaksi'),
                onTap: () {
                  onPageSelected(3); // Index 3 untuk Transaksi
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_rounded),
                title: const Text('Manajemen Produk'),
                onTap: () {
                  onPageSelected(5); // Index 5 untuk Produk
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Pengaturan'),
                onTap: () {
                  onPageSelected(4); // Index 4 untuk Pengaturan
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
