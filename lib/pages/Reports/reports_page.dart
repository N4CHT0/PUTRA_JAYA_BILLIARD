import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/services/firebase_service.dart';
import 'package:putra_jaya_billiard/widgets/transactions_detail_dialog.dart';
// import 'package:putra_jaya_billiard/utils/pdf_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsPage extends StatefulWidget {
  final String userRole;
  const ReportsPage({super.key, required this.userRole});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  int _shift1StartHour = 8;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    final tabLength = widget.userRole == 'admin' ? 4 : 2;
    _tabController = TabController(length: tabLength, vsync: this);
    _loadShiftSettings();
  }

  Future<void> _loadShiftSettings() async {
    final prefs = await SharedPreferences.getInstance();
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
    }
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
            _buildReportView(ReportType.shift),
            _buildReportView(ReportType.daily),
            _buildReportView(ReportType.weekly),
            _buildReportView(ReportType.monthly),
          ]
        : [
            _buildReportView(ReportType.shift),
            _buildReportView(ReportType.daily),
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

  Widget _buildReportView(ReportType type) {
    if (type == ReportType.shift) {
      return _buildRealTimeShiftView();
    }

    DateTime start, end;
    String title;

    switch (type) {
      case ReportType.daily:
        start = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        end = start.add(const Duration(days: 1));
        title =
            'Laporan Harian - ${intl.DateFormat('dd MMMM yyyy').format(_selectedDate)}';
        break;
      case ReportType.weekly:
        start =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7));
        title =
            'Mingguan (${intl.DateFormat('dd MMM').format(start)} - ${intl.DateFormat('dd MMM yyyy').format(end.subtract(const Duration(days: 1)))})';
        break;
      case ReportType.monthly:
        start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        title =
            'Bulanan - ${intl.DateFormat('MMMM yyyy').format(_selectedDate)}';
        break;
      case ReportType.shift:
        return const Center(child: Text("Invalid Report Type"));
    }
    // --- PERBAIKAN: Bungkus dengan SingleChildScrollView agar bisa scroll jika konten panjang ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: _buildGeneralReportBody(start, end, title, isScrollable: false),
    );
  }
  // --- PERBAIKAN UTAMA: Pisahkan logika shift real-time ke metode terpisah ---

  Widget _buildRealTimeShiftView() {
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

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        _buildGeneralReportBody(
            currentShiftStart, currentShiftEnd, currentShiftTitle,
            isScrollable: false),
        const SizedBox(height: 24),
        _buildGeneralReportBody(
            previousShiftStart, previousShiftEnd, previousShiftTitle,
            isScrollable: false),
      ],
    );
  }

  Widget _buildGeneralReportBody(DateTime start, DateTime end, String title,
      {bool isScrollable = true}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getFinancialReportStream(start, end),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        double totalIncome = 0;
        double totalExpense = 0;
        List<Map<String, dynamic>> transactions = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          transactions =
              docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

          for (var trx in transactions) {
            if (trx['flow'] == 'income') {
              totalIncome += (trx['totalAmount'] ?? 0.0);
            } else if (trx['flow'] == 'expense') {
              totalExpense += (trx['totalAmount'] ?? 0.0);
            }
          }
        }
        final double netProfit = totalIncome - totalExpense;

        final formatter = intl.NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

        // --- PERBAIKAN: Ganti Column dengan ListView jika isScrollable, dan bungkus list dengan Expanded ---
        final listContent = transactions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Tidak ada transaksi pada periode ini.',
                      style: TextStyle(color: Colors.grey[400])),
                ),
              )
            : ListView.builder(
                // --- PERBAIKAN: Hapus padding di sini, karena sudah ada di parent ---
                padding: EdgeInsets.zero,
                shrinkWrap:
                    !isScrollable, // Hanya shrinkwrap jika tidak di dalam scrollable parent
                physics: isScrollable
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final trx = transactions[index];
                  return InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) =>
                            TransactionDetailDialog(transactionData: trx),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildTransactionDetailCard(trx, formatter),
                  );
                },
              );

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
            // --- PERBAIKAN UTAMA: Bungkus daftar dengan Expanded agar tidak overflow ---
            // Jika tidak scrollable, bungkus dengan container agar tidak error
            isScrollable ? Expanded(child: listContent) : listContent,
          ],
        );
      },
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
      Map<String, dynamic> trx, intl.NumberFormat formatter) {
    final createdAt = (trx['createdAt'] as Timestamp).toDate();
    final type = trx['type'] ?? 'unknown';
    final isIncome = trx['flow'] == 'income';
    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case 'billiard':
        title = 'Billing Meja ${trx['tableId']}';
        final duration = Duration(seconds: trx['durationInSeconds'] ?? 0);
        subtitle = "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";
        icon = Icons.pool;
        break;
      case 'pos':
        title = 'Penjualan POS';
        subtitle = 'oleh ${trx['cashierName']}';
        icon = Icons.point_of_sale;
        break;
      case 'purchase':
        title = 'Pembelian Stok';
        subtitle = 'dari ${trx['supplierName']}';
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
            '${isIncome ? '+' : '-'} ${formatter.format(trx['totalAmount'])}',
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

enum ReportType { shift, daily, weekly, monthly }
