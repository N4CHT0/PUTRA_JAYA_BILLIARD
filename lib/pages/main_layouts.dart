// lib/pages/main_layouts.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/accounts/accounts_page.dart';
import 'package:putra_jaya_billiard/pages/dashboard/dashboard_page.dart';
import 'package:putra_jaya_billiard/pages/pos/pos_page.dart';
import 'package:putra_jaya_billiard/pages/products/products_page.dart';
import 'package:putra_jaya_billiard/pages/reports/reports_page.dart';
import 'package:putra_jaya_billiard/pages/settings/settings_page.dart';
import 'package:putra_jaya_billiard/pages/transactions/transactions_page.dart';
import 'package:putra_jaya_billiard/widgets/app_drawer.dart';
import 'package:putra_jaya_billiard/widgets/custom_app_bar.dart';
import 'package:window_manager/window_manager.dart'; // <-- 1. IMPORT YANG HILANG

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
        PosPage(currentUser: widget.user), // Index 6
      ],
    ];
  }

  // Fungsi ini sudah benar
  void _toggleNativeFullscreen() async {
    bool isFull = await windowManager.isFullScreen();
    windowManager.setFullScreen(!isFull);
  }

  void _onPageSelected(int index) {
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
        onGoHome: () => _onPageSelected(0),
        onGoToPOS: () {
          if (widget.user.role == 'admin') {
            _onPageSelected(6);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Anda tidak memiliki akses ke halaman POS.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        // --- 2. HUBUNGKAN FUNGSI FULLSCREEN DI SINI ---
        onToggleFullscreen: _toggleNativeFullscreen,
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
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
    );
  }
}
