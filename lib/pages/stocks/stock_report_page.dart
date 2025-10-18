// lib/pages/stocks/stock_report_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:intl/intl.dart';
// Import model LOKAL
import 'package:putra_jaya_billiard/models/local_product.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class StockReportPage extends StatefulWidget {
  // Hapus kodeOrganisasi
  // final String kodeOrganisasi;

  const StockReportPage({super.key}); // Hapus parameter

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  // Gunakan service LOKAL
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  String _searchQuery = '';
  final _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Laporan Stok Produk'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              onChanged: (value) {
                // Trigger rebuild saat search query berubah
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: 'Cari Nama Produk',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            // Tabel Stok (Gunakan ValueListenableBuilder)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                // Gunakan ValueListenableBuilder untuk data produk dari Hive
                child: ValueListenableBuilder<Box<LocalProduct>>(
                  valueListenable: _localDbService.getProductListenable(),
                  builder: (context, box, _) {
                    // Filter produk berdasarkan query pencarian di sini
                    final products = box.values
                        .where((product) =>
                            product.name.toLowerCase().contains(_searchQuery))
                        .toList()
                        .cast<LocalProduct>();

                    // Urutkan produk berdasarkan nama
                    products.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    if (products.isEmpty && _searchQuery.isEmpty) {
                      return const Center(
                          child: Text(
                              'Belum ada produk. Tambahkan di Manajemen Produk.'));
                    } else if (products.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                          child:
                              Text('Produk "$_searchQuery" tidak ditemukan.'));
                    }

                    // Hitung total aset dari produk yang terfilter
                    double totalAssetValue = products.fold(
                        0.0,
                        (sum, product) =>
                            sum + (product.stock * product.purchasePrice));

                    return Column(
                      children: [
                        Expanded(
                          // Gunakan LayoutBuilder agar SingleChildScrollView tahu batasannya
                          child: LayoutBuilder(builder: (context, constraints) {
                            return SingleChildScrollView(
                              // Scroll Vertikal
                              child: SingleChildScrollView(
                                // Scroll Horizontal
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  // Pastikan DataTable minimal selebar parent
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    columnSpacing: 20, // Sesuaikan jarak kolom
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.white.withOpacity(0.1)),
                                    columns: const [
                                      DataColumn(label: Text('Nama Produk')),
                                      DataColumn(label: Text('Satuan')),
                                      DataColumn(
                                          label: Text('Sisa Stok'),
                                          numeric: true),
                                      DataColumn(
                                          label: Text('Harga Beli'),
                                          numeric: true), // Tambah Harga Beli
                                      DataColumn(
                                          label: Text('Nilai Aset'),
                                          numeric: true),
                                    ],
                                    rows: products.map((product) {
                                      final assetValue =
                                          product.stock * product.purchasePrice;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(product.name)),
                                          DataCell(Text(product.unit)),
                                          DataCell(
                                            Text(
                                              product.stock.toString(),
                                              style: TextStyle(
                                                color: product.stock <= 5
                                                    ? Colors.redAccent
                                                    : Colors.white,
                                                fontWeight: product.stock <= 5
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              textAlign: TextAlign
                                                  .end, // Align numeric
                                            ),
                                          ),
                                          // Tampilkan Harga Beli
                                          DataCell(Text(
                                            _currencyFormatter
                                                .format(product.purchasePrice),
                                            textAlign: TextAlign.end,
                                          )),
                                          DataCell(Text(
                                            _currencyFormatter
                                                .format(assetValue),
                                            textAlign: TextAlign.end,
                                          )),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        // Tampilkan Total Aset
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Nilai Aset',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontSize: 18), // Sesuaikan ukuran
                              ),
                              Text(
                                _currencyFormatter.format(totalAssetValue),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: Colors.cyanAccent,
                                        fontSize: 18), // Sesuaikan ukuran
                              ),
                            ],
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
