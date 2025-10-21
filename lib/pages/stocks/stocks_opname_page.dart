// lib/pages/stocks/stocks_opname_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class StockOpnamePage extends StatefulWidget {
  final UserModel currentUser;

  const StockOpnamePage({
    super.key,
    required this.currentUser,
  });

  @override
  State<StockOpnamePage> createState() => _StockOpnamePageState();
}

// Helper class untuk memudahkan pengelolaan data di list
class VariantStockItem {
  final LocalProduct product;
  final ProductVariant variant;
  final dynamic productKey;

  VariantStockItem(
      {required this.product, required this.variant, this.productKey});
}

class _StockOpnamePageState extends State<StockOpnamePage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  // Key sekarang adalah kombinasi productKey dan nama varian
  final Map<String, TextEditingController> _controllers = {};
  String _searchQuery = '';
  List<VariantStockItem> _allItems = [];

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _saveAdjustments() async {
    final List<LocalStockMutation> mutations = [];
    final Map<dynamic, LocalProduct> productsToUpdate = {};

    for (var item in _allItems) {
      final productKey = item.product.key;
      // Buat key unik untuk controller
      final controllerKey = '${productKey}_${item.variant.name}';
      final controller = _controllers[controllerKey];

      if (controller != null && controller.text.isNotEmpty) {
        final physicalCount = int.tryParse(controller.text);

        if (physicalCount != null && item.variant.stock != physicalCount) {
          // Siapkan produk yang akan diupdate
          productsToUpdate.putIfAbsent(
              productKey, () => _localDbService.getProductByKey(productKey)!);

          final productToEdit = productsToUpdate[productKey]!;
          final variantIndex = productToEdit.variants
              .indexWhere((v) => v.name == item.variant.name);

          if (variantIndex != -1) {
            final stockBefore = productToEdit.variants[variantIndex].stock;
            // Update stok varian di produk yang akan disimpan
            productToEdit.variants[variantIndex].stock = physicalCount;

            mutations.add(
              LocalStockMutation(
                productId: productKey.toString(),
                productName:
                    '${item.product.name} (${item.variant.name})', // Nama lebih spesifik
                type: 'adjustment',
                quantityChange: physicalCount - stockBefore,
                stockBefore: stockBefore,
                notes: 'Stok Opname',
                date: DateTime.now(),
                userId: widget.currentUser.uid,
                userName: widget.currentUser.nama,
              ),
            );
          }
        }
      }
    }

    if (productsToUpdate.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak ada perubahan stok untuk disimpan.')),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Konfirmasi Penyesuaian'),
        content: Text(
            'Anda akan menyesuaikan stok untuk ${mutations.length} varian produk. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        for (var mutation in mutations) {
          await _localDbService.addStockMutation(mutation);
        }

        for (var entry in productsToUpdate.entries) {
          await _localDbService.updateProduct(entry.key, entry.value);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Stok berhasil disesuaikan!'),
              backgroundColor: Colors.green),
        );
        _controllers.forEach((key, value) => value.clear());
        setState(() {});
      } catch (e, s) {
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
                labelText: 'Cari Nama Produk atau Varian',
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
                child: ValueListenableBuilder<Box<LocalProduct>>(
                  valueListenable: _localDbService.getProductListenable(),
                  builder: (context, box, _) {
                    _allItems = [];
                    for (var product in box.values) {
                      for (var variant in product.variants) {
                        _allItems.add(VariantStockItem(
                            product: product,
                            variant: variant,
                            productKey: product.key));
                      }
                    }

                    final filteredItems = _allItems.where((item) {
                      final productName = item.product.name.toLowerCase();
                      final variantName = item.variant.name.toLowerCase();
                      return productName.contains(_searchQuery) ||
                          variantName.contains(_searchQuery);
                    }).toList();

                    filteredItems.sort((a, b) =>
                        '${a.product.name} ${a.variant.name}'
                            .compareTo('${b.product.name} ${b.variant.name}'));

                    if (filteredItems.isEmpty) {
                      return const Center(
                          child: Text('Tidak ada produk/varian.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final controllerKey =
                            '${item.productKey}_${item.variant.name}';
                        _controllers.putIfAbsent(
                            controllerKey, () => TextEditingController());

                        return Card(
                          color: Colors.black.withOpacity(0.2),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            title: Text(
                                '${item.product.name} (${item.variant.name})'),
                            subtitle: Text(
                                'Stok Sistem: ${item.variant.stock} ${item.product.unit}'),
                            trailing: SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _controllers[controllerKey],
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
