// lib/reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/pdf_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  int _shift1StartHour = 8; // Default

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pendapatan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Shift'),
            Tab(text: 'Harian'),
            Tab(text: 'Mingguan'),
            Tab(text: 'Bulanan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportView(ReportType.shift),
          _buildReportView(ReportType.daily),
          _buildReportView(ReportType.weekly),
          _buildReportView(ReportType.monthly),
        ],
      ),
    );
  }

  Widget _buildReportView(ReportType type) {
    // Tentukan rentang waktu berdasarkan tipe laporan
    DateTime start, end;
    String title;

    switch (type) {
      case ReportType.shift:
      case ReportType.daily:
        start = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        end = start.add(const Duration(days: 1));
        title =
            'Laporan Harian - ${intl.DateFormat('dd MMMM yyyy').format(_selectedDate)}';
        break;
      case ReportType.weekly:
        start = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7));
        title =
            'Laporan Mingguan (${intl.DateFormat('dd MMM').format(start)} - ${intl.DateFormat('dd MMM yyyy').format(end.subtract(const Duration(days: 1)))})';
        break;
      case ReportType.monthly:
        start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        title =
            'Laporan Bulanan - ${intl.DateFormat('MMMM yyyy').format(_selectedDate)}';
        break;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: type == ReportType.shift
              ? _buildShiftReportBody(start, end)
              : _buildGeneralReportBody(start, end, title),
        ),
      ],
    );
  }

  Widget _buildShiftReportBody(DateTime dayStart, DateTime dayEnd) {
    final shift1EndHour = (_shift1StartHour + 12) % 24;
    final shift1Start = dayStart.add(Duration(hours: _shift1StartHour));
    final shift1End = dayStart.add(Duration(hours: shift1EndHour));

    final DateTime shift2Start, shift2End;
    if (shift1End.isAfter(shift1Start)) {
      // Shift 1 tidak melewati tengah malam
      shift2Start = shift1End;
      shift2End = dayEnd.add(Duration(hours: _shift1StartHour));
    } else {
      // Shift 1 melewati tengah malam (misal mulai jam 20:00)
      shift2Start = shift1End;
      shift2End = shift1Start;
    }

    return Column(
      children: [
        Expanded(
          child: _buildGeneralReportBody(
            shift1Start,
            shift1End,
            'Laporan Shift 1 (${intl.DateFormat('HH:mm').format(shift1Start)} - ${intl.DateFormat('HH:mm').format(shift1End)})',
          ),
        ),
        Expanded(
          child: _buildGeneralReportBody(
            shift2Start,
            shift2End,
            'Laporan Shift 2 (${intl.DateFormat('HH:mm').format(shift2Start)} - ${intl.DateFormat('HH:mm').format(shift2End)})',
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralReportBody(DateTime start, DateTime end, String title) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'Tidak ada transaksi pada periode ini.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final transactions = docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        final totalRevenue = transactions.fold<double>(
          0,
          (sum, item) => sum + (item['totalCost'] as double),
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: Rp${totalRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.tealAccent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final trx = transactions[index];
                  return ListTile(
                    title: Text('Meja ${trx['tableId']}'),
                    subtitle: Text(
                      intl.DateFormat(
                        'dd/MM HH:mm',
                      ).format((trx['startTime'] as Timestamp).toDate()),
                    ),
                    trailing: Text(
                      'Rp${(trx['totalCost'] as double).toStringAsFixed(0)}',
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Cetak Laporan Ini'),
                onPressed: () =>
                    PdfGenerator.printReport(title, transactions, totalRevenue),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum ReportType { shift, daily, weekly, monthly }
