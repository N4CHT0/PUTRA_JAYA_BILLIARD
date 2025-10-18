import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/models/local_transaction.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';
// Import model LOKAL
// Import dialog detail yang sudah diperbaiki
import 'package:putra_jaya_billiard/widgets/transactions_detail_dialog.dart';
// SharedPreferences masih dipakai untuk setting shift
import 'package:shared_preferences/shared_preferences.dart';
// ❌ Hapus import Firestore yang tidak perlu lagi
// import 'package:cloud_firestore/cloud_firestore.dart';

// Enum ReportType (Tetap sama)
enum ReportType { shift, daily, weekly, monthly }

class ReportsPage extends StatefulWidget {
  final String userRole;

  const ReportsPage({
    super.key,
    required this.userRole,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  int _shift1StartHour = 8;
  final LocalDatabaseService _localDbService = LocalDatabaseService();

  List<LocalTransaction> _currentTransactions = [];
  bool _isLoading = false;
  ReportType _currentReportType = ReportType.daily; // Default

  @override
  void initState() {
    super.initState();
    final tabLength = widget.userRole == 'admin' ? 4 : 2;
    _tabController = TabController(length: tabLength, vsync: this);
    _loadShiftSettings();
    _loadReportData(); // Muat data awal saat halaman dibuka

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ReportType newType;
        switch (_tabController.index) {
          case 0:
            newType = ReportType.shift;
            break;
          case 1:
            newType = ReportType.daily;
            break;
          case 2:
            newType = ReportType.weekly;
            break;
          case 3:
            newType = ReportType.monthly;
            break;
          default:
            newType = ReportType.daily;
        }
        if (newType != _currentReportType) {
          _currentReportType = newType;
          _loadReportData();
        } else if (newType == ReportType.shift) {
          _loadReportData();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _shift1StartHour = prefs.getInt('shift1StartHour') ?? 8;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.tealAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReportData();
    }
  }

  void _loadReportData() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    DateTime start, end;
    List<LocalTransaction> fetchedTransactions = [];

    switch (_currentReportType) {
      case ReportType.shift:
        final now = DateTime.now();
        start = now.subtract(const Duration(hours: 36));
        end = now.add(const Duration(hours: 1));
        fetchedTransactions =
            _localDbService.getTransactionsBetween(start, end);
        break;
      case ReportType.daily:
        start = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        end = start.add(const Duration(days: 1));
        fetchedTransactions =
            _localDbService.getTransactionsBetween(start, end);
        break;
      case ReportType.weekly:
        start =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7));
        fetchedTransactions =
            _localDbService.getTransactionsBetween(start, end);
        break;
      case ReportType.monthly:
        start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        fetchedTransactions =
            _localDbService.getTransactionsBetween(start, end);
        break;
    }

    setState(() {
      _currentTransactions = fetchedTransactions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = widget.userRole == 'admin'
        ? const [
            Tab(text: 'Shift'),
            Tab(text: 'Harian'),
            Tab(text: 'Mingguan'),
            Tab(text: 'Bulanan'),
          ]
        : const [
            Tab(text: 'Shift'),
            Tab(text: 'Harian'),
          ];

    final List<Widget> tabViews = widget.userRole == 'admin'
        ? [
            _buildReportViewContent(ReportType.shift),
            _buildReportViewContent(ReportType.daily),
            _buildReportViewContent(ReportType.weekly),
            _buildReportViewContent(ReportType.monthly),
          ]
        : [
            _buildReportViewContent(ReportType.shift),
            _buildReportViewContent(ReportType.daily),
          ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pilih Tanggal',
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang Data',
            onPressed: _loadReportData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
    );
  }

  Widget _buildReportViewContent(ReportType type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (type == ReportType.shift) {
      return _buildShiftViewContent(_currentTransactions);
    }

    String title;
    switch (type) {
      case ReportType.daily:
        title =
            'Laporan Harian - ${intl.DateFormat('dd MMMM yyyy').format(_selectedDate)}';
        break;
      case ReportType.weekly:
        DateTime start =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        DateTime end = start.add(const Duration(days: 7));
        title =
            'Mingguan (${intl.DateFormat('dd MMM').format(start)} - ${intl.DateFormat('dd MMM yyyy').format(end.subtract(const Duration(days: 1)))})';
        break;
      case ReportType.monthly:
        title =
            'Bulanan - ${intl.DateFormat('MMMM yyyy').format(_selectedDate)}';
        break;
      case ReportType.shift:
        return Container();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: _buildGeneralReportBody(_currentTransactions, title),
    );
  }

  Widget _buildShiftViewContent(List<LocalTransaction> allLoadedData) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final shift1Start = today.add(Duration(hours: _shift1StartHour));
    final shift1End = shift1Start.add(const Duration(hours: 12));

    DateTime currentShiftStart, currentShiftEnd;
    DateTime previousShiftStart, previousShiftEnd;
    String currentShiftTitle, previousShiftTitle;

    if (now.isAfter(shift1Start) && now.isBefore(shift1End)) {
      currentShiftStart = shift1Start;
      currentShiftEnd = shift1End;
      currentShiftTitle = "Laporan Shift 1 (Saat Ini)";
      previousShiftStart = shift1Start.subtract(const Duration(hours: 12));
      previousShiftEnd = shift1Start;
      previousShiftTitle = "Laporan Shift 2 (Sebelumnya)";
    } else {
      if (now.isBefore(shift1Start)) {
        currentShiftStart = shift1Start.subtract(const Duration(hours: 12));
        currentShiftEnd = shift1Start;
      } else {
        currentShiftStart = shift1End;
        currentShiftEnd = shift1End.add(const Duration(hours: 12));
      }
      currentShiftTitle = "Laporan Shift 2 (Saat Ini)";
      previousShiftStart = shift1Start;
      previousShiftEnd = shift1End;
      previousShiftTitle = "Laporan Shift 1 (Sebelumnya)";
    }

    final currentShiftTransactions = allLoadedData
        .where((trx) =>
            !trx.createdAt.isBefore(currentShiftStart) &&
            trx.createdAt.isBefore(currentShiftEnd))
        .toList();
    final previousShiftTransactions = allLoadedData
        .where((trx) =>
            !trx.createdAt.isBefore(previousShiftStart) &&
            trx.createdAt.isBefore(previousShiftEnd))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        _buildGeneralReportBody(currentShiftTransactions, currentShiftTitle),
        const SizedBox(height: 24),
        _buildGeneralReportBody(previousShiftTransactions, previousShiftTitle),
      ],
    );
  }

  Widget _buildGeneralReportBody(
      List<LocalTransaction> transactions, String title) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var trx in transactions) {
      if (trx.flow == 'income') {
        totalIncome += trx.totalAmount;
      } else if (trx.flow == 'expense') {
        totalExpense += trx.totalAmount;
      }
    }
    final double netProfit = totalIncome - totalExpense;

    final formatter = intl.NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withOpacity(0.25),
              border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20, color: Colors.white24),
              _buildSummaryRow('Total Pemasukan', totalIncome,
                  Colors.greenAccent, formatter),
              const SizedBox(height: 8),
              _buildSummaryRow('Total Pengeluaran', totalExpense,
                  Colors.redAccent, formatter),
              const Divider(height: 20, color: Colors.white24),
              _buildSummaryRow(
                  'Laba Bersih', netProfit, Colors.cyanAccent, formatter,
                  isLarge: true),
            ],
          ),
        ),
        transactions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Tidak ada transaksi pada periode ini.',
                      style: TextStyle(color: Colors.grey[400])),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final trx = transactions[index];
                  return InkWell(
                    onTap: () {
                      // ✅ PERBAIKAN: Langsung kirim objek 'trx'
                      showDialog(
                        context: context,
                        builder: (_) =>
                            TransactionDetailDialog(transaction: trx),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildTransactionDetailCard(trx, formatter),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSummaryRow(
      String label, double amount, Color color, intl.NumberFormat formatter,
      {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isLarge ? 18 : 14)),
        Text(
          formatter.format(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 20 : 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetailCard(
      LocalTransaction trx, intl.NumberFormat formatter) {
    final createdAt = trx.createdAt;
    final type = trx.type;
    final isIncome = trx.flow == 'income';
    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case 'billiard':
        title = 'Billing Meja ${trx.tableId}';
        final duration = Duration(seconds: trx.durationInSeconds ?? 0);
        subtitle = "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";
        icon = Icons.pool;
        break;
      case 'pos':
        title = 'Penjualan POS';
        final items = trx.items;
        final totalItems = items?.fold<int>(
                0,
                (sum, item) =>
                    sum + ((item['quantity'] ?? 0) as num).toInt()) ??
            0;
        subtitle = '$totalItems item oleh ${trx.cashierName}';
        icon = Icons.point_of_sale;
        break;
      case 'purchase':
        title = 'Pembelian Stok';
        subtitle = 'dari ${trx.supplierName}';
        icon = Icons.shopping_cart;
        break;
      default:
        title = 'Transaksi Lain';
        subtitle = 'Tidak diketahui';
        icon = Icons.receipt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: isIncome ? Colors.greenAccent : Colors.redAccent,
              size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '${intl.DateFormat('dd MMM, HH:mm').format(createdAt)} • $subtitle',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'} ${formatter.format(trx.totalAmount)}',
            style: TextStyle(
                fontSize: 14,
                color: isIncome ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
