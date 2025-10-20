// lib/pages/purchases/purchase_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/local_payment_method.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_supplier.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
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
  String _selectedPaymentMethod = 'Cash'; // ✅ State untuk metode pembayaran

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
              title: const Text('Pilih Produk'),
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
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text('Stok saat ini: ${product.stock}'),
                            onTap: () {
                              Navigator.pop(context);
                              _showItemDetailDialog(product);
                            },
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

  void _showItemDetailDialog(LocalProduct product) {
    final qtyController = TextEditingController(text: '1');
    final priceController =
        TextEditingController(text: product.purchasePrice.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          title: Text('Detail Pembelian: ${product.name}'),
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
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        int.tryParse(value) == null ||
                        int.parse(value) <= 0) {
                      return 'Masukkan jumlah valid';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: priceController,
                  decoration:
                      const InputDecoration(labelText: 'Harga Beli Satuan'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        double.tryParse(value) == null ||
                        double.parse(value) < 0) {
                      return 'Masukkan harga valid';
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
                  setState(() {
                    final existingIndex = _purchaseItems.indexWhere(
                        (item) => (item.product).key == product.key);

                    final qty = int.tryParse(qtyController.text) ?? 1;
                    final price = double.tryParse(priceController.text) ?? 0;

                    if (existingIndex != -1) {
                      _purchaseItems[existingIndex].quantity += qty;
                      _purchaseItems[existingIndex].purchasePrice = price;
                    } else {
                      _purchaseItems.add(
                        PurchaseItem(
                          product: product,
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

  void _removeItem(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
    });
  }

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null || _purchaseItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih supplier dan tambahkan item terlebih dahulu.')));
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        title: const Text('Konfirmasi Pembelian'),
        content: Text(
            'Simpan transaksi pembelian dari ${_selectedSupplier!.name} senilai ${_currencyFormat.format(_totalAmount)}? Stok produk akan diperbarui.'),
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
          paymentMethod: _selectedPaymentMethod, // ✅ Gunakan state
          items: _purchaseItems.map((item) {
            final product = item.product;
            return {
              'productId': product.key.toString(),
              'productName': product.name,
              'quantity': item.quantity,
              'purchasePrice': item.purchasePrice,
            };
          }).toList(),
        );

        await _localDbService.addTransaction(localTransaction);

        for (var item in _purchaseItems) {
          final product = item.product;
          final stockBefore = product.stock;

          final mutation = LocalStockMutation(
            productId: product.key.toString(),
            productName: product.name,
            type: 'purchase',
            quantityChange: item.quantity,
            stockBefore: stockBefore,
            notes: 'Pembelian dari ${_selectedSupplier!.name}',
            date: now,
            userId: widget.currentUser.uid,
            userName: widget.currentUser.nama,
          );
          await _localDbService.addStockMutation(mutation);

          await _localDbService.increaseStockForPurchase(
              product.key, item.quantity, item.purchasePrice);
        }

        setState(() {
          _purchaseItems.clear();
          _selectedSupplier = null;
          _selectedPaymentMethod = 'Cash'; // Reset ke default
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaksi pembelian berhasil disimpan (Lokal)!'),
          backgroundColor: Colors.green,
        ));
      } catch (e, s) {
        print('Error saving purchase: $e');
        print(s);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
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
        title: const Text('Transaksi Pembelian'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSupplierSelector(),
            const SizedBox(height: 16),
            Expanded(child: _buildPurchaseItemsList()),
            _buildSummaryAndSave(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ValueListenableBuilder<Box<LocalSupplier>>(
        valueListenable: _localDbService.getSupplierListenable(),
        builder: (context, box, _) {
          final suppliers = box.values.toList().cast<LocalSupplier>();
          suppliers.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return DropdownButton<LocalSupplier>(
            value: _selectedSupplier,
            hint: const Text('Pilih Supplier'),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2c2c2c),
            items: suppliers.where((s) => s.isActive).map((supplier) {
              return DropdownMenuItem(
                value: supplier,
                child: Text(supplier.name),
              );
            }).toList(),
            onChanged: (LocalSupplier? newValue) {
              setState(() {
                _selectedSupplier = newValue;
              });
            },
          );
        },
      ),
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
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
              ),
            ),
          ),
          Expanded(
            child: _purchaseItems.isEmpty
                ? const Center(child: Text('Belum ada item pembelian.'))
                : ListView.builder(
                    itemCount: _purchaseItems.length,
                    itemBuilder: (context, index) {
                      final item = _purchaseItems[index];
                      final product = item.product;
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                            '${item.quantity} x ${_currencyFormat.format(item.purchasePrice)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currencyFormat
                                .format(item.quantity * item.purchasePrice)),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () => _removeItem(index),
                              tooltip: 'Hapus item',
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndSave() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Pembelian:',
                        style: TextStyle(fontSize: 18)),
                    Text(_currencyFormat.format(_totalAmount),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent)),
                    const SizedBox(height: 16),
                    const Text('Metode Pembayaran:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ValueListenableBuilder<Box<LocalPaymentMethod>>(
                      valueListenable:
                          _localDbService.getPaymentMethodsListenable(),
                      builder: (context, box, _) {
                        final paymentMethods = box.values
                            .where((p) => p.isActive)
                            .map((p) => p.name)
                            .toList();
                        final allOptions = {'Cash', ...paymentMethods}.toList();
                        return DropdownButton<String>(
                          value: _selectedPaymentMethod,
                          isExpanded: true,
                          underline:
                              Container(height: 1, color: Colors.white24),
                          dropdownColor: const Color(0xFF2c2c2c),
                          items: allOptions.map((String value) {
                            return DropdownMenuItem<String>(
                                value: value, child: Text(value));
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedPaymentMethod = newValue);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed:
                    _purchaseItems.isNotEmpty && _selectedSupplier != null
                        ? _savePurchase
                        : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Simpan Transaksi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
