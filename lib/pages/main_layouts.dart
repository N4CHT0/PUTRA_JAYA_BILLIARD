import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/accounts/accounts_page.dart';
import 'package:putra_jaya_billiard/pages/dashboard/dashboard_page.dart';
import 'package:putra_jaya_billiard/pages/pos/pos_page.dart';
import 'package:putra_jaya_billiard/pages/products/products_page.dart';
import 'package:putra_jaya_billiard/pages/purchases/purchase_page.dart';
import 'package:putra_jaya_billiard/pages/reports/reports_page.dart';
import 'package:putra_jaya_billiard/pages/settings/settings_page.dart';
import 'package:putra_jaya_billiard/pages/stocks/stock_card_page.dart';
import 'package:putra_jaya_billiard/pages/stocks/stock_report_page.dart';
import 'package:putra_jaya_billiard/pages/stocks/stocks_opname_page.dart';
import 'package:putra_jaya_billiard/pages/suppliers/suppliers_pages.dart';
import 'package:putra_jaya_billiard/pages/transactions/transactions_page.dart';
import 'package:putra_jaya_billiard/widgets/app_drawer.dart';
import 'package:putra_jaya_billiard/widgets/custom_app_bar.dart';

class MainLayout extends StatefulWidget {
  final UserModel user;
  const MainLayout({super.key, required this.user});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final Map<int, Widget> _pageMap = {};

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  void _buildPages() {
    _pageMap[0] = DashboardPage(user: widget.user);
    _pageMap[1] = ReportsPage(userRole: widget.user.role);
    _pageMap[6] = PosPage(currentUser: widget.user);
    _pageMap[8] = PurchasePage(currentUser: widget.user);
    _pageMap[9] = const StockReportPage();
    _pageMap[11] = const StockCardPage();

    if (widget.user.role == 'admin') {
      _pageMap[2] = AccountsPage(admin: widget.user);
      _pageMap[3] = const TransactionsPage();
      _pageMap[4] = SettingsPage(onSaveComplete: _switchToDashboard);
      _pageMap[5] = const ProductsPage();
      _pageMap[7] = const SuppliersPage();
      _pageMap[10] = StockOpnamePage(currentUser: widget.user);
    }
  }

  void _switchToDashboard() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _onPageSelected(int index) {
    if (_pageMap.containsKey(index)) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        user: widget.user,
        onSettingsChanged: () {},
        onGoHome: _switchToDashboard,
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
          children: List.generate(
            12,
            (index) =>
                _pageMap[index] ??
                Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Text(
                        "Halaman untuk indeks $index tidak tersedia untuk role Anda.",
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
