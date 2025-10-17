import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/accounts/accounts_page.dart';
import 'package:putra_jaya_billiard/pages/dashboard/dashboard_page.dart';
import 'package:putra_jaya_billiard/pages/products/products_page.dart'; // <-- Pastikan import ini ada
import 'package:putra_jaya_billiard/pages/reports/reports_page.dart';
import 'package:putra_jaya_billiard/pages/settings/settings_page.dart';
import 'package:putra_jaya_billiard/pages/transactions/transactions_page.dart';
import 'package:putra_jaya_billiard/widgets/app_drawer.dart';
import 'package:putra_jaya_billiard/widgets/custom_app_bar.dart';
import 'package:putra_jaya_billiard/pages/pos/pos_page.dart';

class MainLayout extends StatefulWidget {
  final UserModel user;
  const MainLayout({super.key, required this.user});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(user: widget.user), // Index 0
      ReportsPage(userRole: widget.user.role), // Index 1
      if (widget.user.role == 'admin') ...[
        AccountsPage(admin: widget.user), // Index 2
        const TransactionsPage(), // Index 3
        const SettingsPage(), // Index 4
        const ProductsPage(), // Index 5
        PosPage(
            currentUser:
                widget.user), // <-- Tambahkan halaman POS di sini (Index 6)
      ],
    ];
  }

  void _onPageSelected(int index) {
    // Cek keamanan sederhana agar tidak error jika indeks di luar jangkauan
    if (index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handleSettingsChanged() {
    print("Settings changed, potentially reload rates here.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        user: widget.user,
        onSettingsChanged: _handleSettingsChanged,
        onGoHome: () => _onPageSelected(0), // Kembali ke dashboard (index 0)
      ),
      drawer: AppDrawer(user: widget.user, onPageSelected: _onPageSelected),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // Gunakan IndexedStack agar state halaman tidak hilang saat berpindah
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
    );
  }
}
