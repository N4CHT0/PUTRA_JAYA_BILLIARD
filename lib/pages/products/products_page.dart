// lib/pages/products/products_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive Flutter
import 'package:intl/intl.dart';
// Import model LOKAL
import 'package:putra_jaya_billiard/models/local_product.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class ProductsPage extends StatefulWidget {
  // Hapus kodeOrganisasi jika tidak diperlukan lagi
  // final String kodeOrganisasi;

  const ProductsPage({super.key}); // Hapus parameter

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Gunakan service LOKAL
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Dialog untuk menambah atau mengedit produk (sekarang pakai LocalProduct)
  void _showProductDialog({LocalProduct? product, dynamic productKey}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name);
    final unitController = TextEditingController(text: product?.unit);
    final purchasePriceController =
        TextEditingController(text: product?.purchasePrice.toString() ?? '0');
    final sellingPriceController =
        TextEditingController(text: product?.sellingPrice.toString() ?? '0');
    // Stok awal hanya bisa diatur saat tambah produk, saat edit diambil dari data
    final stockController = TextEditingController(
        text: product == null ? '0' : product.stock.toString());
    bool isActive = product?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(product == null ? 'Tambah Produk Baru' : 'Edit Produk',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Nama Produk'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: unitController,
                          decoration: const InputDecoration(
                              labelText: 'Satuan (e.g., btl, porsi)'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: sellingPriceController,
                          decoration:
                              const InputDecoration(labelText: 'Harga Jual'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null ||
                                v.isEmpty ||
                                double.tryParse(v) == null ||
                                double.parse(v) < 0) {
                              return 'Harga jual tidak valid';
                            }
                            return null;
                          }),
                      TextFormField(
                          controller: purchasePriceController,
                          decoration:
                              const InputDecoration(labelText: 'Harga Beli'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null ||
                                v.isEmpty ||
                                double.tryParse(v) == null ||
                                double.parse(v) < 0) {
                              return 'Harga beli tidak valid';
                            }
                            return null;
                          }),
                      // Stok hanya bisa diinput saat TAMBAH produk baru
                      if (product == null)
                        TextFormField(
                            controller: stockController,
                            decoration:
                                const InputDecoration(labelText: 'Stok Awal'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null ||
                                  v.isEmpty ||
                                  int.tryParse(v) == null ||
                                  int.parse(v) < 0) {
                                return 'Stok awal tidak valid';
                              }
                              return null;
                            }),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Produk Aktif'),
                        value: isActive,
                        onChanged: (bool? value) =>
                            setState(() => isActive = value ?? true),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.teal,
                      )
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newProduct = LocalProduct(
                    // id tidak perlu diisi saat tambah, Hive akan generate key
                    name: nameController.text,
                    unit: unitController.text,
                    sellingPrice:
                        double.tryParse(sellingPriceController.text) ?? 0,
                    purchasePrice:
                        double.tryParse(purchasePriceController.text) ?? 0,
                    // Saat edit, stok tidak diubah dari sini (diubah via opname/transaksi)
                    stock: product?.stock ??
                        int.tryParse(stockController.text) ??
                        0,
                    isActive: isActive,
                  );

                  try {
                    if (product == null) {
                      // Tambah produk baru ke Hive
                      await _localDbService.addProduct(newProduct);
                    } else {
                      // Update produk yang ada di Hive menggunakan key
                      await _localDbService.updateProduct(
                          productKey, newProduct);
                    }
                    if (!mounted) return; // Mounted check
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Gagal menyimpan: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // Fungsi konfirmasi hapus (sekarang pakai key)
  Future<void> _showDeleteConfirmation(
      LocalProduct product, dynamic productKey) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Produk?'),
        content: Text(
            'Anda yakin ingin menghapus ${product.name}? Ini akan menghapus data produk secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _localDbService
            .deleteProduct(productKey); // Gunakan key untuk hapus
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${product.name} berhasil dihapus.'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Manajemen Produk'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showProductDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Produk'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                // Gunakan ValueListenableBuilder untuk data Hive
                child: ValueListenableBuilder<Box<LocalProduct>>(
                  valueListenable: _localDbService.getProductListenable(),
                  builder: (context, box, _) {
                    final products = box.values.toList().cast<LocalProduct>();

                    if (products.isEmpty) {
                      return const Center(child: Text('Belum ada produk.'));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.all(
                              Colors.white.withOpacity(0.1)),
                          columns: const [
                            DataColumn(label: Text('Nama')),
                            DataColumn(label: Text('Satuan')),
                            DataColumn(
                                label: Text('Harga Jual'), numeric: true),
                            DataColumn(
                                label: Text('Harga Beli'), numeric: true),
                            DataColumn(label: Text('Stok'), numeric: true),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: products.map((product) {
                            // Dapatkan key Hive untuk item ini
                            final productKey = product.key;
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(product.unit)),
                                DataCell(Text(_currencyFormat
                                    .format(product.sellingPrice))),
                                DataCell(Text(_currencyFormat
                                    .format(product.purchasePrice))),
                                DataCell(Text(product.stock.toString(),
                                    style: TextStyle(
                                        color: product.stock <= 5
                                            ? Colors.redAccent
                                            : Colors.white,
                                        fontWeight: product.stock <= 5
                                            ? FontWeight.bold
                                            : FontWeight.normal))),
                                DataCell(
                                  Icon(
                                    product.isActive
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: product.isActive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _showProductDialog(
                                            product: product,
                                            productKey:
                                                productKey), // Kirim key
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showDeleteConfirmation(product,
                                                productKey), // Kirim key
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
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
