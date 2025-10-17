// lib/pages/stock_opname/stock_opname_page.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/stock_adjustment_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class StockOpnamePage extends StatefulWidget {
  final UserModel currentUser;
  const StockOpnamePage({super.key, required this.currentUser});

  @override
  State<StockOpnamePage> createState() => _StockOpnamePageState();
}

class _StockOpnamePageState extends State<StockOpnamePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, TextEditingController> _controllers = {};
  String _searchQuery = '';
  List<Product> _allProducts = []; // Simpan daftar produk lengkap di state

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // --- FUNGSI YANG DIPERBAIKI ---
  void _saveAdjustments() {
    final List<StockAdjustment> adjustments = [];

    // Iterasi melalui daftar produk yang ada di state, bukan controllers
    for (var product in _allProducts) {
      final controller = _controllers[product.id!];
      // Cek apakah ada controller dan isinya tidak kosong
      if (controller != null && controller.text.isNotEmpty) {
        final physicalCount = int.tryParse(controller.text);

        // Cek jika ada perubahan antara stok sistem dan stok fisik yang diinput
        if (physicalCount != null && product.stock != physicalCount) {
          adjustments.add(
            StockAdjustment(
              productId: product.id!,
              productName: product.name,
              previousStock: product.stock,
              newStock: physicalCount,
              reason: 'Stok Opname',
              userId: widget.currentUser.uid,
              userName: widget.currentUser.nama,
              adjustmentDate: DateTime.now(),
            ),
          );
        }
      }
    }

    if (adjustments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak ada perubahan stok untuk disimpan.')),
      );
      return;
    }

    _showConfirmationDialog(adjustments);
  }

  void _showConfirmationDialog(List<StockAdjustment> adjustments) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Konfirmasi Penyesuaian'),
        content: Text(
            'Anda akan menyesuaikan stok untuk ${adjustments.length} produk. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              try {
                await _firebaseService.performStockAdjustment(
                    adjustments, widget.currentUser);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Stok berhasil disesuaikan!'),
                      backgroundColor: Colors.green),
                );
                // Kosongkan semua controller setelah berhasil
                _controllers.forEach((key, value) => value.clear());
                setState(() {});
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Stok Opname'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan Perubahan',
            onPressed: _saveAdjustments,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                labelText: 'Cari Nama Produk',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
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

                    _allProducts =
                        snapshot.data!; // Simpan data produk ke state
                    final filteredProducts = _allProducts
                        .where(
                            (p) => p.name.toLowerCase().contains(_searchQuery))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        _controllers.putIfAbsent(
                            product.id!, () => TextEditingController());

                        return Card(
                          color: Colors.black.withOpacity(0.2),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                                'Stok Sistem: ${product.stock} ${product.unit}'),
                            trailing: SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _controllers[product.id!],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stok Fisik',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
