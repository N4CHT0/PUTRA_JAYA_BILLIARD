// lib/pages/products/products_page.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  void _showProductDialog({LocalProduct? product, dynamic productKey}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name);
    final unitController = TextEditingController(text: product?.unit);
    bool isActive = product?.isActive ?? true;
    List<ProductVariant> variants = List<ProductVariant>.from(product?.variants
            .map((v) => ProductVariant(
                name: v.name,
                purchasePrice: v.purchasePrice,
                sellingPrice: v.sellingPrice,
                stock: v.stock)) ??
        []);

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
                          decoration: const InputDecoration(
                              labelText: 'Nama Grup Produk (e.g., Kopi, Mie)'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: unitController,
                          decoration: const InputDecoration(
                              labelText: 'Satuan (e.g., gelas, porsi)'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      const Text('Varian Produk',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (variants.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Wajib memiliki minimal 1 varian.',
                              style: TextStyle(
                                  color: Colors.amberAccent, fontSize: 12)),
                        ),
                      Column(
                        children: variants.asMap().entries.map((entry) {
                          int idx = entry.key;
                          ProductVariant variant = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(variant.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Stok: ${variant.stock} | Jual: ${_currencyFormat.format(variant.sellingPrice)} | Beli: ${_currencyFormat.format(variant.purchasePrice)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.amber),
                                  onPressed: () async {
                                    final updatedVariant =
                                        await _showVariantDialog(
                                            variant: variant);
                                    if (updatedVariant != null) {
                                      setState(() {
                                        variants[idx] = updatedVariant;
                                      });
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() {
                                      variants.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah Varian'),
                          onPressed: () async {
                            final newVariant = await _showVariantDialog();
                            if (newVariant != null) {
                              setState(() {
                                variants.add(newVariant);
                              });
                            }
                          },
                        ),
                      ),
                      const Divider(color: Colors.white24),
                      CheckboxListTile(
                        title: const Text('Grup Produk Aktif'),
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
                if (formKey.currentState!.validate() && variants.isNotEmpty) {
                  final newProduct = LocalProduct(
                    name: nameController.text,
                    unit: unitController.text,
                    isActive: isActive,
                    variants: variants,
                  );

                  try {
                    if (product == null) {
                      await _localDbService.addProduct(newProduct);
                    } else {
                      await _localDbService.updateProduct(
                          productKey, newProduct);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Gagal menyimpan: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                } else if (variants.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Gagal menyimpan: Produk harus memiliki setidaknya satu varian.'),
                    backgroundColor: Colors.orange,
                  ));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<ProductVariant?> _showVariantDialog({ProductVariant? variant}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: variant?.name);
    final purchasePriceController =
        TextEditingController(text: variant?.purchasePrice.toString());
    final sellingPriceController =
        TextEditingController(text: variant?.sellingPrice.toString());
    final stockController =
        TextEditingController(text: variant?.stock.toString());

    return showDialog<ProductVariant>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF3c3c3c),
          title: Text(variant == null ? 'Tambah Varian Baru' : 'Edit Varian'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'Nama Varian (e.g., Goreng, Ori)'),
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: sellingPriceController,
                    decoration: const InputDecoration(labelText: 'Harga Jual'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty || double.tryParse(v) == null)
                            ? 'Harga tidak valid'
                            : null,
                  ),
                  TextFormField(
                    controller: purchasePriceController,
                    decoration: const InputDecoration(labelText: 'Harga Beli'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty || double.tryParse(v) == null)
                            ? 'Harga tidak valid'
                            : null,
                  ),
                  TextFormField(
                    controller: stockController,
                    decoration: InputDecoration(
                        labelText:
                            variant == null ? 'Stok Awal' : 'Stok Saat Ini'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty || int.tryParse(v) == null)
                            ? 'Stok tidak valid'
                            : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newVariant = ProductVariant(
                    name: nameController.text,
                    sellingPrice: double.parse(sellingPriceController.text),
                    purchasePrice: double.parse(purchasePriceController.text),
                    stock: int.parse(stockController.text),
                  );
                  Navigator.pop(context, newVariant);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
      LocalProduct product, dynamic productKey) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Grup Produk?'),
        content: Text(
            'Anda yakin ingin menghapus ${product.name} beserta semua variannya? Ini akan menghapus data secara permanen.'),
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
        await _localDbService.deleteProduct(productKey);
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
              label: const Text('Tambah Grup Produk'),
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
                            DataColumn(label: Text('Nama Grup')),
                            DataColumn(label: Text('Satuan')),
                            DataColumn(label: Text('Harga Jual')),
                            DataColumn(label: Text('Total Stok')),
                            DataColumn(label: Text('Varian')),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: products.map((product) {
                            final productKey = product.key;

                            // ===== FIX ADA DI SINI =====
                            // Cek dulu apakah list varian kosong sebelum memanggil reduce.
                            // Jika kosong, berikan nilai default 0.0.
                            double minPrice = product.variants.isNotEmpty
                                ? product.variants
                                    .map((v) => v.sellingPrice)
                                    .reduce((a, b) => a < b ? a : b)
                                : 0.0;

                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(product.unit)),
                                DataCell(Text(product.hasVariants
                                    ? 'Mulai dari ${_currencyFormat.format(minPrice)}'
                                    : '-')),
                                DataCell(Text(product.totalStock.toString(),
                                    style: TextStyle(
                                        color: product.totalStock <= 5
                                            ? Colors.redAccent
                                            : Colors.white))),
                                DataCell(
                                    Text(product.variants.length.toString())),
                                DataCell(Icon(
                                  product.isActive
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: product.isActive
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                )),
                                DataCell(
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _showProductDialog(
                                            product: product,
                                            productKey: productKey),
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
                                            _showDeleteConfirmation(
                                                product, productKey),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Hapus'),
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
