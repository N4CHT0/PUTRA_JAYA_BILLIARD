import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';
// Note: Anda mungkin perlu membuat cara untuk mendapatkan user yang sedang login.
// Untuk sekarang, kita akan asumsikan user didapat dari widget tree (misal: via Provider)
// atau dilempar sebagai argumen. Di sini kita akan lempar sebagai argumen.

class PosPage extends StatefulWidget {
  final UserModel currentUser;
  const PosPage({super.key, required this.currentUser});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<CartItem> _cart = [];
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  void _addToCart(Product product) {
    setState(() {
      // Cek apakah produk sudah ada di keranjang
      for (var item in _cart) {
        if (item.product.id == product.id) {
          item.quantity++;
          return;
        }
      }
      // Jika belum ada, tambahkan baru
      _cart.add(CartItem(product: product));
    });
  }

  void _updateQuantity(CartItem item, int change) {
    setState(() {
      item.quantity += change;
      if (item.quantity <= 0) {
        _cart.remove(item);
      }
    });
  }

  double get _totalPrice {
    double total = 0;
    for (var item in _cart) {
      total += item.product.sellingPrice * item.quantity;
    }
    return total;
  }

  void _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keranjang masih kosong!')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Transaksi'),
        content: Text(
            'Total belanja: ${_currencyFormat.format(_totalPrice)}\nLanjutkan pembayaran?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firebaseService.saveSalesTransactionAndDecreaseStock(
                    _cart, widget.currentUser);
                setState(() => _cart.clear());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Transaksi berhasil!'),
                  backgroundColor: Colors.green,
                ));
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kolom Kiri: Daftar Produk
            Expanded(
              flex: 2,
              child: _buildProductList(),
            ),
            const SizedBox(width: 16),
            // Kolom Kanan: Keranjang Belanja
            Expanded(
              flex: 1,
              child: _buildCart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<List<Product>>(
        stream: _firebaseService.getProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada produk.'));
          }
          final products = snapshot.data!.where((p) => p.isActive).toList();
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 3 / 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return InkWell(
                onTap: () => _addToCart(product),
                child: Card(
                  color: const Color(0xFF2c2c2c),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(_currencyFormat.format(product.sellingPrice)),
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
          const Divider(height: 24),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Keranjang kosong'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.product.name),
                        subtitle: Text(_currencyFormat
                            .format(item.product.sellingPrice * item.quantity)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => _updateQuantity(item, -1),
                              iconSize: 18,
                            ),
                            Text(item.quantity.toString(),
                                style: const TextStyle(fontSize: 16)),
                            IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _updateQuantity(item, 1),
                                iconSize: 18),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_currencyFormat.format(_totalPrice),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkout,
              icon: const Icon(Icons.payment),
              label: const Text('Bayar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}
