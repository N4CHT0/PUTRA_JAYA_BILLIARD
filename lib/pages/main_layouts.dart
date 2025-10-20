// lib/layout/main_layout.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/accounts/accounts_page.dart';
import 'package:putra_jaya_billiard/pages/dashboard/dashboard_page.dart';
import 'package:putra_jaya_billiard/pages/members/members_page.dart';
import 'package:putra_jaya_billiard/pages/pos/pos_page.dart';
import 'package:putra_jaya_billiard/pages/products/products_page.dart';
import 'package:putra_jaya_billiard/pages/purchases/purchase_page.dart';
import 'package:putra_jaya_billiard/pages/reports/reports_page.dart';
import 'package:putra_jaya_billiard/pages/settings/general_settings_page.dart';
import 'package:putra_jaya_billiard/pages/settings/payment_methods_page.dart';
import 'package:putra_jaya_billiard/pages/settings/settings_page.dart';
import 'package:putra_jaya_billiard/pages/stocks/stock_card_page.dart';
import 'package:putra_jaya_billiard/pages/stocks/stock_report_page.dart';
import 'package:putra_jaya_billiard/pages/stocks/stocks_opname_page.dart';
import 'package:putra_jaya_billiard/pages/suppliers/suppliers_pages.dart';
import 'package:putra_jaya_billiard/pages/transactions/transactions_page.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';
import 'package:putra_jaya_billiard/services/printer_service.dart'; // FIX: Import printer_service
import 'package:putra_jaya_billiard/widgets/app_drawer.dart';
import 'package:putra_jaya_billiard/widgets/custom_app_bar.dart';
import 'package:window_manager/window_manager.dart';

class MainLayout extends StatefulWidget {
  final UserModel user;
  final ArduinoService arduinoService;
  // FIX: Ganti tipe data dari ArduinoService ke PrinterService
  final PrinterService printerService;

  const MainLayout({
    super.key,
    required this.user,
    required this.arduinoService,
    required this.printerService,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final Map<int, Widget> _pageMap = {};

  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  @override
  void dispose() {
    widget.arduinoService.dispose();
    widget.printerService.dispose();
    super.dispose();
  }

  void _handleAddToCartToTable(int tableId, List<CartItem> items) {
    _dashboardKey.currentState?.addToCartToTable(tableId, items);
    _onPageSelected(0);
  }

  List<int> _getActiveTableIds() {
    return _dashboardKey.currentState?.getActiveTableIds() ?? [];
  }

  void _buildPages() {
    // Halaman yang bisa diakses semua role
    _pageMap[0] = DashboardPage(
      key: _dashboardKey,
      user: widget.user,
      arduinoService: widget.arduinoService,
      printerService: widget.printerService,
    );
    _pageMap[1] = ReportsPage(userRole: widget.user.role);
    _pageMap[6] = PosPage(
      currentUser: widget.user,
      onAddToCartToTable: _handleAddToCartToTable,
      getActiveTableIds: _getActiveTableIds,
      arduinoService: widget.arduinoService,
      printerService: widget.printerService,
    );
    _pageMap[8] = PurchasePage(currentUser: widget.user);
    _pageMap[9] = const StockReportPage();
    _pageMap[11] = const StockCardPage();

    // Halaman khusus admin
    if (widget.user.role == 'admin') {
      _pageMap[2] = AccountsPage(admin: widget.user);
      _pageMap[3] = const TransactionsPage();
      _pageMap[4] = SettingsPage(onSaveComplete: _switchToDashboard);
      _pageMap[5] = const ProductsPage();
      _pageMap[7] = const SuppliersPage();
      _pageMap[10] = StockOpnamePage(currentUser: widget.user);
      _pageMap[12] = const MembersPage();
      _pageMap[13] = const GeneralSettingsPage();
      _pageMap[14] = const PaymentMethodsPage();
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
      if (widget.user.role != 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Halaman ini hanya untuk Admin.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  void _toggleNativeFullscreen() async {
    bool isFull = await windowManager.isFullScreen();
    windowManager.setFullScreen(!isFull);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        user: widget.user,
        onSettingsChanged: () => _onPageSelected(4),
        onGoHome: _switchToDashboard,
        onGoToPOS: () => _onPageSelected(6),
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
          children: List.generate(
            15,
            (index) =>
                _pageMap[index] ??
                const Center(
                  child: Text(
                    "Halaman tidak tersedia untuk role Anda.",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
