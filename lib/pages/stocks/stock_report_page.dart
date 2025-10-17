import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final FirebaseService _firebaseService = FirebaseService();
  String _searchQuery = '';

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
            // Tabel Stok
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                child: StreamBuilder<List<Product>>(
                  stream: _firebaseService.getProductsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Tidak ada produk.'));
                    }

                    // Filter produk berdasarkan query pencarian
                    final products = snapshot.data!
                        .where((product) =>
                            product.name.toLowerCase().contains(_searchQuery))
                        .toList();

                    return SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 38,
                        headingRowColor: MaterialStateProperty.all(
                            Colors.white.withOpacity(0.1)),
                        columns: const [
                          DataColumn(label: Text('Nama Produk')),
                          DataColumn(label: Text('Satuan')),
                          DataColumn(label: Text('Sisa Stok'), numeric: true),
                        ],
                        rows: products.map((product) {
                          return DataRow(
                            cells: [
                              DataCell(Text(product.name)),
                              DataCell(Text(product.unit)),
                              DataCell(
                                Text(
                                  product.stock.toString(),
                                  style: TextStyle(
                                    color: product.stock <= 5
                                        ? Colors
                                            .redAccent // Beri warna merah jika stok menipis
                                        : Colors.white,
                                    fontWeight: product.stock <= 5
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
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
