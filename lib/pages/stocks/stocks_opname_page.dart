// lib/pages/stocks/stocks_opname_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
// Import model LOKAL
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
// Import user model (masih dari Firebase Auth)
import 'package:putra_jaya_billiard/models/user_model.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class StockOpnamePage extends StatefulWidget {
  final UserModel currentUser; // User info dari Firebase Auth
  // Hapus kodeOrganisasi
  // final String kodeOrganisasi;

  const StockOpnamePage({
    super.key,
    required this.currentUser,
    // required this.kodeOrganisasi, // Hapus
  });

  @override
  State<StockOpnamePage> createState() => _StockOpnamePageState();
}

class _StockOpnamePageState extends State<StockOpnamePage> {
  // Gunakan service LOKAL
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  // Simpan controller dalam Map<dynamic, TextEditingController>
  // karena key Hive bisa jadi int atau String
  final Map<dynamic, TextEditingController> _controllers = {};
  String _searchQuery = '';
  // Simpan daftar produk lengkap di state untuk referensi saat menyimpan
  List<LocalProduct> _allProducts = [];

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // --- Fungsi Simpan Penyesuaian (Diubah Total) ---
  void _saveAdjustments() async {
    // Jadikan async
    final List<LocalStockMutation> mutations = []; // Simpan mutasi di sini
    final Map<dynamic, int> adjustments = {}; // Simpan key dan stok baru

    // Iterasi melalui daftar produk yang ditampilkan/disimpan di state
    for (var product in _allProducts) {
      final key = product.key; // Dapatkan key Hive produk
      final controller = _controllers[key];

      // Cek jika ada controller dan isinya diinput angka
      if (controller != null && controller.text.isNotEmpty) {
        final physicalCount = int.tryParse(controller.text);

        // Cek jika ada perubahan antara stok sistem (product.stock) dan stok fisik
        if (physicalCount != null && product.stock != physicalCount) {
          // Tambahkan ke map adjustments untuk update produk nanti
          adjustments[key] = physicalCount;

          // Buat objek mutasi stok
          mutations.add(
            LocalStockMutation(
              productId: key.toString(), // Simpan key Hive sbg ID
              productName: product.name,
              type: 'adjustment', // Tipe penyesuaian
              quantityChange: physicalCount - product.stock, // Perbedaan
              stockBefore: product.stock,
              notes: 'Stok Opname',
              date: DateTime.now(),
              userId: widget.currentUser.uid,
              userName: widget.currentUser.nama,
            ),
          );
        }
      }
    }

    if (adjustments.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak ada perubahan stok untuk disimpan.')),
      );
      return;
    }

    // Tampilkan dialog konfirmasi sebelum menyimpan
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Konfirmasi Penyesuaian'),
        content: Text(
            'Anda akan menyesuaikan stok untuk ${adjustments.length} produk. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true), // Konfirmasi simpan
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return; // Mounted check sebelum async utama
      try {
        // Simpan semua mutasi stok ke Hive
        for (var mutation in mutations) {
          await _localDbService.addStockMutation(mutation);
        }

        // Update stok produk di Hive satu per satu
        adjustments.forEach((key, newStock) async {
          // Dapatkan produk asli dari box untuk update
          final productToUpdate = _localDbService.getProductByKey(key);
          if (productToUpdate != null) {
            productToUpdate.stock = newStock;
            await _localDbService.updateProduct(key, productToUpdate);
          }
        });

        if (!mounted) return; // Mounted check setelah async
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Stok berhasil disesuaikan!'),
              backgroundColor: Colors.green),
        );
        // Kosongkan semua controller setelah berhasil
        _controllers.forEach((key, value) => value.clear());
        setState(() {}); // Refresh UI
      } catch (e, s) {
        // Tambah stack trace
        print('Error saving adjustments: $e');
        print(s);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            onPressed: _saveAdjustments, // Panggil fungsi simpan yang baru
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
                // Gunakan ValueListenableBuilder untuk produk dari Hive
                child: ValueListenableBuilder<Box<LocalProduct>>(
                  valueListenable: _localDbService.getProductListenable(),
                  builder: (context, box, _) {
                    // Filter produk berdasarkan search query
                    _allProducts = box.values
                        .toList()
                        .cast<LocalProduct>(); // Update list lengkap
                    final filteredProducts = _allProducts
                        .where(
                            (p) => p.name.toLowerCase().contains(_searchQuery))
                        .toList();
                    // Urutkan berdasarkan nama
                    filteredProducts.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    if (filteredProducts.isEmpty && _searchQuery.isEmpty) {
                      return const Center(child: Text('Tidak ada produk.'));
                    } else if (filteredProducts.isEmpty &&
                        _searchQuery.isNotEmpty) {
                      return Center(
                          child:
                              Text('Produk "$_searchQuery" tidak ditemukan.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final productKey = product.key; // Dapatkan key Hive

                        // Buat controller jika belum ada untuk key ini
                        _controllers.putIfAbsent(
                            productKey, () => TextEditingController());

                        return Card(
                          color: Colors.black.withOpacity(0.2),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                                'Stok Sistem: ${product.stock} ${product.unit}'),
                            trailing: SizedBox(
                              width: 120, // Lebar field input stok fisik
                              child: TextField(
                                controller: _controllers[productKey],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stok Fisik',
                                  border: OutlineInputBorder(),
                                  isDense: true, // Agar lebih ringkas
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
