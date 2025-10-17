// lib/pages/reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/utils/pdf_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsPage extends StatefulWidget {
  // --- PERUBAHAN 1: Menambahkan parameter untuk menerima userRole ---
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

  @override
  void initState() {
    super.initState();
    // --- PERUBAHAN 2: Jumlah tab ditentukan oleh role ---
    final tabLength =
        widget.userRole == 'admin' ? 4 : 2; // Admin: 4 tab, Pegawai: 2 tab
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
    // --- PERUBAHAN 3: Daftar tab dan view dibuat dinamis berdasarkan role ---
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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Laporan Pendapatan'),
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
            tabs: tabs, // Menggunakan daftar tab dinamis
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: tabViews, // Menggunakan daftar view dinamis
        ),
      ),
    );
  }

  Widget _buildReportView(ReportType type) {
    DateTime start, end;
    String title;

    switch (type) {
      case ReportType.shift:
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
    }

    if (type == ReportType.shift) {
      return _buildShiftReportBody(start, end);
    } else {
      return _buildGeneralReportBody(start, end, title);
    }
  }

  Widget _buildShiftReportBody(DateTime dayStart, DateTime dayEnd) {
    final shift1EndHour = (_shift1StartHour + 12) % 24;
    final shift1Start = dayStart.add(Duration(hours: _shift1StartHour));
    DateTime shift1End;
    if (shift1EndHour < _shift1StartHour) {
      shift1End = dayStart.add(Duration(days: 1, hours: shift1EndHour));
    } else {
      shift1End = dayStart.add(Duration(hours: shift1EndHour));
    }
    final shift2Start = shift1End;
    final shift2End = shift1Start.add(const Duration(days: 1));
    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        _buildGeneralReportBody(
          shift1Start,
          shift1End,
          'Laporan Shift 1 (${intl.DateFormat('HH:mm').format(shift1Start)} - ${intl.DateFormat('HH:mm').format(shift1End)})',
        ),
        const SizedBox(height: 16),
        _buildGeneralReportBody(
          shift2Start,
          shift2End,
          'Laporan Shift 2 (${intl.DateFormat('HH:mm').format(shift2Start)} - ${intl.DateFormat('HH:mm').format(shift2End)})',
        ),
      ],
    );
  }

  Widget _buildGeneralReportBody(DateTime start, DateTime end, String title) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('startTime', isGreaterThanOrEqualTo: start)
          .where('startTime', isLessThan: end)
          .orderBy('startTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Tidak ada transaksi pada periode:\n$title',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], height: 1.5),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        final transactions =
            docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        final totalRevenue = transactions.fold<double>(
          0,
          (sum, item) => sum + (item['totalCost'] ?? 0.0),
        );
        final formatter = intl.NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
        return Column(
          children: [
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(0.25),
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Text(
                    formatter.format(totalRevenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final trx = transactions[index];
                  final startTime = (trx['startTime'] as Timestamp).toDate();
                  final duration =
                      Duration(seconds: trx['durationInSeconds'] ?? 0);
                  final durationString =
                      "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meja ${trx['tableId']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              '${intl.DateFormat('dd MMM, HH:mm').format(startTime)} • $durationString',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                        Text(
                          formatter.format(trx['totalCost']),
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // --- PERUBAHAN 4: Tombol cetak hanya muncul untuk admin ---
            if (widget.userRole == 'admin')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak Laporan Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => PdfGenerator.printReport(
                      title, transactions, totalRevenue),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum ReportType { shift, daily, weekly, monthly }
