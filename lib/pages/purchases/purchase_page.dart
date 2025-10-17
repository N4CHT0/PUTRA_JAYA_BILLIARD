// lib/pages/purchase/purchase_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/purchase_item_model.dart';
import 'package:putra_jaya_billiard/models/supplier_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class PurchasePage extends StatefulWidget {
  final UserModel currentUser;
  const PurchasePage({super.key, required this.currentUser});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<PurchaseItem> _purchaseItems = [];
  Supplier? _selectedSupplier;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  double get _totalAmount {
    return _purchaseItems.fold(
        0, (sum, item) => sum + (item.purchasePrice * item.quantity));
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<Product>>(
          stream: _firebaseService.getProductsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final products = snapshot.data!;
            return AlertDialog(
              title: const Text('Pilih Produk'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      title: Text(product.name),
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

  void _showItemDetailDialog(Product product) {
    final qtyController = TextEditingController(text: '1');
    final priceController =
        TextEditingController(text: product.purchasePrice.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail Pembelian: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Kuantitas'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Harga Beli'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _purchaseItems.add(
                    PurchaseItem(
                      product: product,
                      quantity: int.tryParse(qtyController.text) ?? 1,
                      purchasePrice: double.tryParse(priceController.text) ?? 0,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  void _savePurchase() async {
    if (_selectedSupplier == null || _purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih supplier dan tambahkan item terlebih dahulu.')));
      return;
    }

    try {
      // <-- POIN PENTING 2: Data pengguna (widget.currentUser) dikirim dari sini
      await _firebaseService.savePurchaseAndUpdateStock(
          _purchaseItems, _selectedSupplier!, widget.currentUser);

      setState(() {
        _purchaseItems.clear();
        _selectedSupplier = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transaksi pembelian berhasil disimpan!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 16),
        child: Column(
          children: [
            _buildSupplierSelector(),
            const SizedBox(height: 16),
            Expanded(child: _buildPurchaseItemsTable()),
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
      child: StreamBuilder<List<Supplier>>(
        stream: _firebaseService.getSuppliersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Memuat supplier...'));
          }
          final suppliers = snapshot.data!;
          return DropdownButton<Supplier>(
            value: _selectedSupplier,
            hint: const Text('Pilih Supplier'),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: suppliers.map((supplier) {
              return DropdownMenuItem(
                value: supplier,
                child: Text(supplier.name),
              );
            }).toList(),
            onChanged: (Supplier? newValue) {
              setState(() {
                _selectedSupplier = newValue;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildPurchaseItemsTable() {
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
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text(
                            '${item.quantity} x ${_currencyFormat.format(item.purchasePrice)}'),
                        trailing: Text(_currencyFormat
                            .format(item.quantity * item.purchasePrice)),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Pembelian:', style: TextStyle(fontSize: 18)),
              Text(_currencyFormat.format(_totalAmount),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent)),
            ],
          ),
          ElevatedButton(
            onPressed: _savePurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Simpan Transaksi'),
          ),
        ],
      ),
    );
  }
}
