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
    final purchasePriceController =
        TextEditingController(text: product?.purchasePrice.toString() ?? '0');
    final sellingPriceController =
        TextEditingController(text: product?.sellingPrice.toString() ?? '0');
    final stockController =
        TextEditingController(text: product?.stock.toString() ?? '0');
    bool isActive = product?.isActive ?? true;

    List<ProductVariant> variants =
        List<ProductVariant>.from(product?.variants ?? []);

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
                  bool hasVariants = variants.isNotEmpty;

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
                          enabled: !hasVariants,
                          decoration: InputDecoration(
                              labelText: hasVariants
                                  ? 'Harga Jual (ditentukan oleh varian)'
                                  : 'Harga Jual'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (!hasVariants &&
                                (v == null ||
                                    v.isEmpty ||
                                    double.tryParse(v) == null ||
                                    double.parse(v) < 0)) {
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
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      const Text('Varian Produk',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (variants.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                              'Belum ada varian. Harga jual utama akan digunakan.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      Column(
                        children: variants.map((variant) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(variant.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_currencyFormat.format(variant.price)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() {
                                      variants.remove(variant);
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
                            final newVariant = await _showAddVariantDialog();
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
                    name: nameController.text,
                    unit: unitController.text,
                    sellingPrice:
                        double.tryParse(sellingPriceController.text) ?? 0,
                    purchasePrice:
                        double.tryParse(purchasePriceController.text) ?? 0,
                    stock: product?.stock ??
                        int.tryParse(stockController.text) ??
                        0,
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
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<ProductVariant?> _showAddVariantDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    return showDialog<ProductVariant>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF3c3c3c),
          title: const Text('Tambah Varian Baru'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nama Varian (e.g., Double Shot)'),
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Harga Varian'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null ||
                        v.isEmpty ||
                        double.tryParse(v) == null ||
                        double.parse(v) < 0) {
                      return 'Harga tidak valid';
                    }
                    return null;
                  },
                ),
              ],
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
                    price: double.parse(priceController.text),
                  );
                  Navigator.pop(context, newVariant);
                }
              },
              child: const Text('Tambah'),
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
                            DataColumn(label: Text('Harga Jual')),
                            DataColumn(label: Text('Harga Beli')),
                            DataColumn(label: Text('Stok'), numeric: true),
                            DataColumn(label: Text('Varian'), numeric: true),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: products.map((product) {
                            final productKey = product.key;
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(Text(product.hasVariants
                                    ? 'Ada Varian'
                                    : _currencyFormat
                                        .format(product.sellingPrice))),
                                DataCell(Text(_currencyFormat
                                    .format(product.purchasePrice))),
                                DataCell(Text(product.stock.toString(),
                                    style: TextStyle(
                                        color: product.stock <= 5
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
