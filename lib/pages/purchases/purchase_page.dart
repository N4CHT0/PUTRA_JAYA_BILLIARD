// lib/pages/purchases/purchase_page.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/local_payment_method.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_supplier.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';
import 'package:putra_jaya_billiard/models/purchase_item_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class PurchasePage extends StatefulWidget {
  final UserModel currentUser;

  const PurchasePage({
    super.key,
    required this.currentUser,
  });

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final List<PurchaseItem> _purchaseItems = [];
  LocalSupplier? _selectedSupplier;
  String _selectedPaymentMethod = 'Cash';

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  double get _totalAmount {
    return _purchaseItems.fold(
        0, (sum, item) => sum + (item.purchasePrice * item.quantity));
  }

  void _showAddProductDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<Box<LocalProduct>>(
          valueListenable: _localDbService.getProductListenable(),
          builder: (context, box, _) {
            final products = box.values.toList().cast<LocalProduct>();
            products.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return AlertDialog(
              backgroundColor: const Color(0xFF2c2c2c),
              title: const Text('Pilih Produk (Varian)'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: products.isEmpty
                    ? const Center(child: Text('Tidak ada produk.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ExpansionTile(
                            title: Text(product.name),
                            children: product.variants.map((variant) {
                              return ListTile(
                                title: Text(variant.name),
                                subtitle:
                                    Text('Stok saat ini: ${variant.stock}'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showItemDetailDialog(product, variant);
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'))
              ],
            );
          },
        );
      },
    );
  }

  void _showItemDetailDialog(LocalProduct product, ProductVariant variant) {
    final qtyController = TextEditingController(text: '1');
    final priceController =
        TextEditingController(text: variant.purchasePrice.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          title: Text('Detail: ${product.name} (${variant.name})'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Kuantitas'),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  validator: (value) => (value == null ||
                          value.isEmpty ||
                          int.tryParse(value) == null ||
                          int.parse(value) <= 0)
                      ? 'Jumlah tidak valid'
                      : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration:
                      const InputDecoration(labelText: 'Harga Beli Satuan'),
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null ||
                          value.isEmpty ||
                          double.tryParse(value) == null ||
                          double.parse(value) < 0)
                      ? 'Harga tidak valid'
                      : null,
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
                  setState(() {
                    final existingIndex = _purchaseItems.indexWhere((item) =>
                        item.product.key == product.key &&
                        item.variant.name == variant.name);

                    final qty = int.tryParse(qtyController.text) ?? 1;
                    final price = double.tryParse(priceController.text) ?? 0;

                    if (existingIndex != -1) {
                      _purchaseItems[existingIndex].quantity += qty;
                      _purchaseItems[existingIndex].purchasePrice = price;
                    } else {
                      _purchaseItems.add(
                        PurchaseItem(
                          product: product,
                          variant: variant,
                          quantity: qty,
                          purchasePrice: price,
                        ),
                      );
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Tambah/Update'),
            ),
          ],
        );
      },
    );
  }

  // FIX: Fungsi ini ditambahkan karena hilang dari kode Anda
  void _removeItem(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
    });
  }

  Future<void> _savePurchase() async {
    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daftar pembelian masih kosong.')),
      );
      return;
    }
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih supplier terlebih dahulu.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // FIX: Dialog konfirmasi ditambahkan karena hilang dari kode Anda
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        title: const Text('Konfirmasi Pembelian'),
        content: Text(
            'Anda akan menyimpan transaksi pembelian senilai ${_currencyFormat.format(_totalAmount)} dari supplier ${_selectedSupplier!.name}. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final now = DateTime.now();

        final localTransaction = LocalTransaction(
          flow: 'expense',
          type: 'purchase',
          totalAmount: _totalAmount,
          createdAt: now,
          cashierId: widget.currentUser.uid,
          cashierName: widget.currentUser.nama,
          supplierId: _selectedSupplier!.key.toString(),
          supplierName: _selectedSupplier!.name,
          paymentMethod: _selectedPaymentMethod,
          items: _purchaseItems.map((item) {
            return {
              'productId': item.product.key.toString(),
              'productName': '${item.product.name} (${item.variant.name})',
              'quantity': item.quantity,
              'purchasePrice': item.purchasePrice,
            };
          }).toList(),
        );

        await _localDbService.addTransaction(localTransaction);

        for (var item in _purchaseItems) {
          final product = item.product;
          final variant = item.variant;
          final stockBefore = variant.stock;

          final mutation = LocalStockMutation(
            productId: product.key.toString(),
            productName: '${product.name} (${variant.name})',
            type: 'purchase',
            quantityChange: item.quantity,
            stockBefore: stockBefore,
            notes: 'Pembelian dari ${_selectedSupplier!.name}',
            date: now,
            userId: widget.currentUser.uid,
            userName: widget.currentUser.nama,
          );
          await _localDbService.addStockMutation(mutation);

          await _localDbService.updateVariantStockForPurchase(
              product.key, variant.name, item.quantity, item.purchasePrice);
        }

        // FIX: Reset state dan tampilkan notifikasi setelah berhasil
        setState(() {
          _purchaseItems.clear();
          _selectedSupplier = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaksi pembelian berhasil disimpan!'),
          backgroundColor: Colors.green,
        ));
      } catch (e, s) {
        print('Error saving purchase: $e\n$s');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan pembelian: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // FIX: Seluruh method build ditambahkan karena hilang dari kode Anda
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Pembelian Stok'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildPurchaseItemsList(),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildSummaryAndActionPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryAndActionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ringkasan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24, color: Colors.white24),
          const Text('Supplier:', style: TextStyle(color: Colors.grey)),
          _buildSupplierSelector(),
          const SizedBox(height: 16),
          const Text('Metode Pembayaran:',
              style: TextStyle(color: Colors.grey)),
          _buildPaymentMethodSelector(),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembelian',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_currencyFormat.format(_totalAmount),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _savePurchase,
            icon: const Icon(Icons.save),
            label: const Text('Simpan Transaksi Pembelian'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierSelector() {
    return ValueListenableBuilder<Box<LocalSupplier>>(
      valueListenable: _localDbService.getSupplierListenable(),
      builder: (context, box, _) {
        final suppliers = box.values.toList().cast<LocalSupplier>();
        return DropdownButtonFormField<LocalSupplier>(
          value: _selectedSupplier,
          decoration: const InputDecoration(
            isDense: true,
          ),
          hint: const Text('Pilih Supplier'),
          isExpanded: true,
          dropdownColor: const Color(0xFF2c2c2c),
          items: suppliers
              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
              .toList(),
          onChanged: (value) => setState(() => _selectedSupplier = value),
        );
      },
    );
  }

  Widget _buildPaymentMethodSelector() {
    return ValueListenableBuilder<Box<LocalPaymentMethod>>(
      valueListenable: _localDbService.getPaymentMethodsListenable(),
      builder: (context, box, _) {
        final paymentMethods =
            box.values.where((p) => p.isActive).map((p) => p.name).toList();
        final allOptions = {'Cash', ...paymentMethods}.toList();

        return DropdownButtonFormField<String>(
          value: _selectedPaymentMethod,
          decoration: const InputDecoration(isDense: true),
          isExpanded: true,
          dropdownColor: const Color(0xFF2c2c2c),
          items: allOptions
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedPaymentMethod = value);
            }
          },
        );
      },
    );
  }

  Widget _buildPurchaseItemsList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Item'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: _purchaseItems.isEmpty
                ? const Center(child: Text('Belum ada item pembelian.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _purchaseItems.length,
                    itemBuilder: (context, index) {
                      final item = _purchaseItems[index];
                      return Card(
                        color: Colors.black.withOpacity(0.2),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                              '${item.product.name} (${item.variant.name})'),
                          subtitle: Text(
                              '${item.quantity} ${item.product.unit} x ${_currencyFormat.format(item.purchasePrice)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  _currencyFormat.format(
                                      item.quantity * item.purchasePrice),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _removeItem(index),
                                tooltip: 'Hapus item',
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
