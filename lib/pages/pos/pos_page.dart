// lib/pages/pos/pos_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/member_model.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class PosPage extends StatefulWidget {
  final UserModel currentUser;
  const PosPage({super.key, required this.currentUser});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<CartItem> _cart = [];
  Member? _selectedMember;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  void _addToCart(Product product) {
    setState(() {
      for (var item in _cart) {
        if (item.product.id == product.id) {
          if (item.quantity < product.stock) {
            item.quantity++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stok ${product.name} tidak mencukupi.')),
            );
          }
          return;
        }
      }
      if (product.stock > 0) {
        _cart.add(CartItem(product: product));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok ${product.name} habis.')),
        );
      }
    });
  }

  void _updateQuantity(CartItem item, int change) {
    setState(() {
      final newQuantity = item.quantity + change;
      if (newQuantity <= 0) {
        _cart.remove(item);
      } else if (newQuantity <= item.product.stock) {
        item.quantity = newQuantity;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok ${item.product.name} tidak mencukupi.')),
        );
      }
    });
  }

  double get _subtotal {
    return _cart.fold(
        0, (sum, item) => sum + (item.product.sellingPrice * item.quantity));
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

  void _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keranjang masih kosong!')));
      return;
    }

    showDialog(
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              try {
                // --- PERBAIKAN DI SINI ---
                // Mengirim semua parameter yang dibutuhkan
                await _firebaseService.saveSalesTransactionAndDecreaseStock(
                  _cart,
                  widget.currentUser,
                  member: _selectedMember,
                  subtotal: _subtotal,
                  discount: _discountAmount,
                  finalTotal: _totalPrice,
                );
                setState(() {
                  _cart.clear();
                  _selectedMember = null;
                });
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
            Expanded(flex: 2, child: _buildProductList()),
            const SizedBox(width: 16),
            Expanded(flex: 1, child: _buildCartSide()),
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
                                    color: Colors.grey[400], fontSize: 12)),
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
    return Column(
      children: [
        _buildMemberSelector(),
        const SizedBox(height: 16),
        Expanded(child: _buildCart()),
      ],
    );
  }

  Widget _buildMemberSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<List<Member>>(
        stream: _firebaseService.getMembersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: Text('Memuat member...'));
          final members = snapshot.data!;
          List<DropdownMenuItem<Member?>> items = [
            const DropdownMenuItem<Member?>(
              value: null,
              child: Text('Pelanggan Umum'),
            ),
            ...members.where((m) => m.isActive).map((member) {
              return DropdownMenuItem<Member?>(
                value: member,
                child: Text(member.name),
              );
            }).toList(),
          ];

          return DropdownButton<Member?>(
            value: _selectedMember,
            hint: const Text('Pilih Member (Opsional)'),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: (Member? newValue) {
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
          _buildPriceRow('Subtotal:', _subtotal),
          if (_discountAmount > 0)
            _buildPriceRow('Diskon (${_selectedMember!.discountPercentage}%):',
                -_discountAmount,
                color: Colors.amberAccent),
          const Divider(),
          _buildPriceRow('Total:', _totalPrice, isTotal: true),
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
