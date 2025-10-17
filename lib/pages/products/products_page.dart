import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Dialog untuk menambah atau mengedit produk
  void _showProductDialog({Product? product}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name);
    final unitController = TextEditingController(text: product?.unit);
    final purchasePriceController =
        TextEditingController(text: product?.purchasePrice.toString());
    final sellingPriceController =
        TextEditingController(text: product?.sellingPrice.toString());
    final stockController =
        TextEditingController(text: product?.stock.toString());
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
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: purchasePriceController,
                          decoration:
                              const InputDecoration(labelText: 'Harga Beli'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: stockController,
                          decoration: const InputDecoration(labelText: 'Stok'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newProduct = Product(
                    id: product?.id,
                    name: nameController.text,
                    unit: unitController.text,
                    sellingPrice: double.parse(sellingPriceController.text),
                    purchasePrice: double.parse(purchasePriceController.text),
                    stock: int.parse(stockController.text),
                    isActive: isActive,
                  );

                  if (product == null) {
                    _firebaseService.addProduct(newProduct);
                  } else {
                    _firebaseService.updateProduct(newProduct);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showProductDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add New'),
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
                      return const Center(child: Text('Belum ada produk.'));
                    }

                    final products = snapshot.data!;

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.all(
                              Colors.white.withOpacity(0.1)),
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Nama')),
                            DataColumn(label: Text('Satuan')),
                            DataColumn(label: Text('Harga Jual')),
                            DataColumn(label: Text('Harga Beli')),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: products.map((product) {
                            return DataRow(
                              cells: [
                                DataCell(Text(product.id!.substring(0, 6))),
                                DataCell(Text(product.name)),
                                DataCell(Text(product.unit)),
                                DataCell(Text(_currencyFormat
                                    .format(product.sellingPrice))),
                                DataCell(Text(_currencyFormat
                                    .format(product.purchasePrice))),
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
                                            product: product),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _firebaseService
                                            .deleteProduct(product.id!),
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
