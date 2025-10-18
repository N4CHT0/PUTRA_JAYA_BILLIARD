// lib/pages/stocks/stock_card_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:intl/intl.dart';
// Import model LOKAL
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class StockCardPage extends StatefulWidget {
  // Hapus kodeOrganisasi
  // final String kodeOrganisasi;

  const StockCardPage({super.key}); // Hapus parameter

  @override
  State<StockCardPage> createState() => _StockCardPageState();
}

class _StockCardPageState extends State<StockCardPage> {
  // Gunakan service LOKAL
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  // Simpan key Hive dari produk yang dipilih
  dynamic _selectedProductKey;
  // State untuk menyimpan data mutasi
  List<LocalStockMutation> _mutations = [];
  bool _isLoadingMutations = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Kartu Stok'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProductSelector(),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedProductKey == null
                    ? const Center(
                        child: Text(
                            'Silakan pilih produk untuk melihat riwayat stok.'))
                    : _buildMutationTable(), // Tampilkan tabel jika produk dipilih
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dropdown Pilih Produk (Baca dari Hive) ---
  Widget _buildProductSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      // Gunakan ValueListenableBuilder untuk produk dari Hive
      child: ValueListenableBuilder<Box<LocalProduct>>(
        valueListenable: _localDbService.getProductListenable(),
        builder: (context, box, _) {
          final products = box.values.toList().cast<LocalProduct>();
          // Urutkan berdasarkan nama
          products.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          // Pastikan selectedKey masih valid
          final currentSelectionExists =
              products.any((p) => p.key == _selectedProductKey);
          if (!currentSelectionExists) {
            _selectedProductKey = null; // Reset jika produk sudah dihapus
          }

          return DropdownButton<dynamic>(
            // Value-nya adalah key (dynamic)
            value: _selectedProductKey,
            hint: const Text('Pilih Produk'),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2c2c2c),
            items: products.map((product) {
              return DropdownMenuItem<dynamic>(
                value: product.key, // Value-nya adalah key Hive
                child: Text(product.name),
              );
            }).toList(),
            onChanged: (dynamic newValue) {
              setState(() {
                _selectedProductKey = newValue;
                // Muat data mutasi untuk produk yang baru dipilih
                _loadMutations();
              });
            },
          );
        },
      ),
    );
  }

  // --- Fungsi untuk Memuat Data Mutasi ---
  void _loadMutations() {
    if (_selectedProductKey == null) {
      setState(() => _mutations = []);
      return;
    }
    setState(() => _isLoadingMutations = true);

    // Ambil produk terpilih untuk mendapatkan ID string-nya jika disimpan di mutasi
    final selectedProduct =
        _localDbService.getProductByKey(_selectedProductKey);
    if (selectedProduct == null) {
      setState(() {
        _mutations = [];
        _isLoadingMutations = false;
      });
      return;
    }

    // Asumsi mutasi menyimpan product key sebagai string ID
    // Jika mutasi menyimpan ID asli produk (misal dari Firebase dulu), gunakan selectedProduct.id
    final productIdString =
        selectedProduct.key.toString(); // Atau selectedProduct.id jika perlu

    // Ambil data mutasi dari Hive (ini synchronous)
    final fetchedMutations =
        _localDbService.getMutationsForProduct(productIdString);

    setState(() {
      _mutations = fetchedMutations;
      _isLoadingMutations = false;
    });
  }

  // --- Tabel Riwayat Mutasi (Baca dari state _mutations) ---
  Widget _buildMutationTable() {
    if (_isLoadingMutations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mutations.isEmpty) {
      return const Center(
          child: Text('Tidak ada riwayat mutasi untuk produk ini.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor:
                    MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
                columns: const [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Keterangan')),
                  DataColumn(label: Text('Oleh')),
                  DataColumn(label: Text('Masuk'), numeric: true),
                  DataColumn(label: Text('Keluar'), numeric: true),
                  DataColumn(label: Text('Sisa'), numeric: true),
                ],
                rows: _mutations.map((mutation) {
                  final quantityChange = mutation.quantityChange;
                  final stockAfter = mutation.stockAfter; // Gunakan getter
                  return DataRow(cells: [
                    DataCell(Text(
                        DateFormat('dd/MM/yy HH:mm').format(mutation.date))),
                    DataCell(Text(mutation.notes)),
                    DataCell(Text(mutation.userName)),
                    DataCell(Text(
                        quantityChange > 0 ? quantityChange.toString() : '',
                        textAlign: TextAlign.end)),
                    DataCell(Text(
                        quantityChange < 0 ? (-quantityChange).toString() : '',
                        textAlign: TextAlign.end)),
                    DataCell(
                      Text(
                        stockAfter.toString(),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
