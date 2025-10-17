import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/stock_mutation_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class StockCardPage extends StatefulWidget {
  const StockCardPage({super.key});

  @override
  State<StockCardPage> createState() => _StockCardPageState();
}

class _StockCardPageState extends State<StockCardPage> {
  final FirebaseService _firebaseService = FirebaseService();
  // --- PERBAIKAN 1: Simpan ID produk (String), bukan seluruh objek ---
  String? _selectedProductId;

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
                // --- PERBAIKAN 2: Cek apakah ID sudah dipilih ---
                child: _selectedProductId == null
                    ? const Center(
                        child: Text(
                            'Silakan pilih produk untuk melihat riwayat stok.'))
                    : _buildMutationTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<List<Product>>(
        stream: _firebaseService.getProductsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Memuat produk...'));
          }
          final products = snapshot.data!;
          // --- PERBAIKAN 3: Gunakan String sebagai tipe DropdownButton ---
          return DropdownButton<String>(
            value: _selectedProductId,
            hint: const Text('Pilih Produk'),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: products.map((product) {
              return DropdownMenuItem<String>(
                value: product.id, // Value-nya adalah ID (String)
                child: Text(product.name),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedProductId = newValue;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildMutationTable() {
    // --- PERBAIKAN 4: Gunakan ID yang tersimpan untuk query ---
    return StreamBuilder<List<StockMutation>>(
      stream: _firebaseService.getStockMutationsStream(_selectedProductId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('Tidak ada riwayat mutasi untuk produk ini.'));
        }
        final mutations = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                        Colors.white.withOpacity(0.1)),
                    columns: const [
                      DataColumn(label: Text('Tanggal')),
                      DataColumn(label: Text('Keterangan')),
                      DataColumn(label: Text('Oleh')),
                      DataColumn(label: Text('Masuk'), numeric: true),
                      DataColumn(label: Text('Keluar'), numeric: true),
                      DataColumn(label: Text('Sisa'), numeric: true),
                    ],
                    rows: mutations.map((mutation) {
                      final quantityChange = mutation.quantityChange;
                      return DataRow(cells: [
                        DataCell(Text(DateFormat('dd/MM/yy HH:mm')
                            .format(mutation.date))),
                        DataCell(Text(mutation.notes)),
                        DataCell(Text(mutation.userName)),
                        DataCell(Text(
                            quantityChange > 0 ? quantityChange.toString() : '',
                            textAlign: TextAlign.end)),
                        DataCell(Text(
                            quantityChange < 0
                                ? (-quantityChange).toString()
                                : '',
                            textAlign: TextAlign.end)),
                        DataCell(
                          Text(
                            mutation.stockAfter.toString(),
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
      },
    );
  }
}
