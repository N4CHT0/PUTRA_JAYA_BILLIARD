// lib/pages/pos/pos_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
// Import model LOKAL
import 'package:putra_jaya_billiard/models/local_member.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
// Import user model (masih dipakai dari Firebase Auth)
import 'package:putra_jaya_billiard/models/user_model.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class PosPage extends StatefulWidget {
  final UserModel currentUser; // Masih pakai UserModel dari Firebase Auth
  // Hapus kodeOrganisasi
  // final String kodeOrganisasi;

  const PosPage({
    super.key,
    required this.currentUser,
    // required this.kodeOrganisasi, // Hapus
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  // Gunakan service LOKAL
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final List<CartItem> _cart = [];
  LocalMember? _selectedMember; // Gunakan LocalMember

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // --- Fungsi AddToCart perlu diubah sedikit ---
  void _addToCart(LocalProduct product) {
    // Terima LocalProduct
    setState(() {
      final index = _cart.indexWhere((item) =>
          (item.product as LocalProduct).key ==
          product.key); // Bandingkan key Hive
      if (index != -1) {
        if (_cart[index].quantity < product.stock) {
          _cart[index].quantity++;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok ${product.name} tidak mencukupi.')),
          );
        }
      } else {
        if (product.stock > 0) {
          _cart.add(CartItem(
              product: product)); // Product sekarang adalah LocalProduct
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok ${product.name} habis.')),
          );
        }
      }
    });
  }

  // --- Fungsi Update Quantity ---
  void _updateQuantity(CartItem item, int change) {
    setState(() {
      final product = item.product as LocalProduct; // Cast ke LocalProduct
      final newQuantity = item.quantity + change;
      if (newQuantity <= 0) {
        _cart.remove(item);
      } else if (newQuantity <= product.stock) {
        item.quantity = newQuantity;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok ${product.name} tidak mencukupi.')),
        );
      }
    });
  }

  // --- Kalkulasi Harga (Perlu cast product) ---
  double get _subtotal {
    return _cart.fold(
        0,
        (sum, item) =>
            sum +
            ((item.product as LocalProduct).sellingPrice * item.quantity));
  }

  double get _discountAmount {
    if (_selectedMember == null || _selectedMember!.discountPercentage == 0) {
      return 0;
    }
    return _subtotal * (_selectedMember!.discountPercentage / 100);
  }

  double get _totalPrice {
    return _subtotal - _discountAmount;
  }

  // --- Fungsi Checkout Diubah Total ---
  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedMember = null;
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keranjang masih kosong!')));
      return;
    }

    if (!mounted) return; // Mounted check sebelum async
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Konfirmasi Transaksi'),
        content: Text('Subtotal: ${_currencyFormat.format(_subtotal)}\n'
            'Diskon: - ${_currencyFormat.format(_discountAmount)}\n'
            'Total: ${_currencyFormat.format(_totalPrice)}\n\n'
            'Atas nama: ${_selectedMember?.name ?? "Pelanggan Umum"}\nLanjutkan pembayaran?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true), // Konfirmasi bayar
            child: const Text('Bayar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return; // Mounted check sebelum async utama
      try {
        final now = DateTime.now();

        // 1. Buat Objek Transaksi Lokal
        final localTransaction = LocalTransaction(
          flow: 'income',
          type: 'pos',
          totalAmount: _totalPrice,
          createdAt: now,
          cashierId: widget.currentUser.uid,
          cashierName: widget.currentUser.nama,
          subtotal: _subtotal,
          discount: _discountAmount,
          memberId: _selectedMember?.key.toString(), // Simpan key Hive sbg ID
          memberName: _selectedMember?.name,
          items: _cart.map((item) {
            final product = item.product as LocalProduct;
            return {
              'productId': product.key.toString(), // Simpan key Hive sbg ID
              'productName': product.name,
              'quantity': item.quantity,
              'price': product.sellingPrice,
            };
          }).toList(),
        );

        // 2. Simpan Transaksi Lokal
        await _localDbService.addTransaction(localTransaction);

        // 3. Update Stok Produk Lokal & Buat Mutasi Stok Lokal
        for (var item in _cart) {
          final product = item.product as LocalProduct;
          final stockBefore = product.stock;

          // Buat Mutasi Stok Lokal
          final mutation = LocalStockMutation(
            productId: product.key.toString(), // Gunakan key Hive
            productName: product.name,
            type: 'sale', // Simpan tipe sebagai string
            quantityChange: -item.quantity,
            stockBefore: stockBefore,
            notes: 'POS Transaksi', // Bisa tambahkan ID unik lokal jika perlu
            date: now,
            userId: widget.currentUser.uid,
            userName: widget.currentUser.nama,
          );
          // Simpan Mutasi Lokal
          await _localDbService.addStockMutation(mutation);

          // Update Stok Produk Lokal (menggunakan key Hive)
          await _localDbService.decreaseStockForSale(
              product.key, item.quantity);
        }

        setState(() {
          _cart.clear();
          _selectedMember = null;
        });

        if (!mounted) return; // Mounted check setelah async
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaksi berhasil disimpan (Lokal)!'),
          backgroundColor: Colors.green,
        ));
      } catch (e, s) {
        // Tambah stack trace
        print('Error during checkout: $e');
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
        title: const Text('Point of Sale (POS)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Kosongkan Keranjang',
            onPressed: _cart.isNotEmpty ? _clearCart : null,
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align top
        children: [
          Expanded(flex: 2, child: _buildProductList()),
          const VerticalDivider(width: 1, color: Colors.white24),
          Expanded(flex: 1, child: _buildCartSide()),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Container(
      margin: const EdgeInsets.all(8.0), // Tambah margin
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      // Gunakan ValueListenableBuilder untuk produk dari Hive
      child: ValueListenableBuilder<Box<LocalProduct>>(
        valueListenable: _localDbService.getProductListenable(),
        builder: (context, box, _) {
          final products = box.values
              .where((p) => p.isActive) // Filter produk aktif
              .toList()
              .cast<LocalProduct>();

          if (products.isEmpty) {
            return const Center(child: Text('Tidak ada produk aktif.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 3 / 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return InkWell(
                onTap: () => _addToCart(product),
                borderRadius: BorderRadius.circular(8),
                child: Card(
                  color: const Color(0xFF2c2c2c),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Stok: ${product.stock}",
                                style: TextStyle(
                                    color: product.stock <= 5
                                        ? Colors.redAccent
                                        : Colors.grey[400], // Warna stok
                                    fontSize: 12)),
                            Text(_currencyFormat.format(product.sellingPrice),
                                style:
                                    const TextStyle(color: Colors.cyanAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCartSide() {
    return Container(
      // Bungkus Column dengan Container
      margin: const EdgeInsets.all(8.0), // Tambah margin
      child: Column(
        children: [
          _buildMemberSelector(),
          const SizedBox(height: 16),
          Expanded(child: _buildCart()),
        ],
      ),
    );
  }

  Widget _buildMemberSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      // Gunakan ValueListenableBuilder untuk member dari Hive
      child: ValueListenableBuilder<Box<LocalMember>>(
        valueListenable: _localDbService.getMemberListenable(),
        builder: (context, box, _) {
          final members = box.values.toList().cast<LocalMember>();
          List<DropdownMenuItem<LocalMember?>> items = [
            const DropdownMenuItem<LocalMember?>(
              value: null,
              child: Text('Pelanggan Umum'),
            ),
            ...members.where((m) => m.isActive).map((member) {
              // Filter member aktif
              return DropdownMenuItem<LocalMember?>(
                value: member,
                child: Text(member.name),
              );
            }).toList(),
          ];

          return DropdownButton<LocalMember?>(
            value: _selectedMember,
            hint: const Text('Pilih Member (Opsional)'),
            isExpanded: true,
            underline: const SizedBox.shrink(), // Hapus garis bawah
            dropdownColor: const Color(0xFF2c2c2c), // Warna dropdown
            items: items,
            onChanged: (LocalMember? newValue) {
              setState(() => _selectedMember = newValue);
            },
          );
        },
      ),
    );
  }

  Widget _buildCart() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Keranjang',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24, color: Colors.white24), // Warna divider
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Keranjang kosong'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      final product = item.product as LocalProduct; // Cast
                      return ListTile(
                        dense: true, // Buat lebih ringkas
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name),
                        subtitle: Text(_currencyFormat
                            .format(product.sellingPrice * item.quantity)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints:
                                  const BoxConstraints(), // Hapus padding default
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20,
                                  color: Colors.amber), // Icon & warna
                              onPressed: () => _updateQuantity(item, -1),
                            ),
                            Text(item.quantity.toString(),
                                style: const TextStyle(fontSize: 16)),
                            IconButton(
                              constraints:
                                  const BoxConstraints(), // Hapus padding default
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20,
                                  color: Colors.cyanAccent), // Icon & warna
                              onPressed: () => _updateQuantity(item, 1),
                            ),
                            IconButton(
                              // Tombol hapus item dari cart
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.only(left: 8),
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.redAccent),
                              onPressed: () =>
                                  setState(() => _cart.removeAt(index)),
                              tooltip: 'Hapus item',
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 24, color: Colors.white24),
          _buildPriceRow('Subtotal:', _subtotal),
          if (_discountAmount > 0)
            _buildPriceRow('Diskon (${_selectedMember!.discountPercentage}%):',
                -_discountAmount,
                color: Colors.amberAccent),
          const Divider(color: Colors.white24), // Warna divider
          _buildPriceRow('Total:', _totalPrice, isTotal: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cart.isNotEmpty
                  ? _checkout
                  : null, // Disable jika cart kosong
              icon: const Icon(Icons.payment),
              label: const Text('Bayar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)) // Border radius
                  ),
            ),
          )
        ],
      ),
    );
  }

  // Widget helper _buildPriceRow (sudah ada sebelumnya, pastikan benar)
  Widget _buildPriceRow(String label, double amount,
      {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(_currencyFormat.format(amount),
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color:
                      color ?? (isTotal ? Colors.cyanAccent : Colors.white))),
        ],
      ),
    );
  }
}
