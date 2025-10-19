import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/local_member.dart';
import 'package:putra_jaya_billiard/models/local_payment_method.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_stock_mutation.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class PosPage extends StatefulWidget {
  final UserModel currentUser;
  final Function(int, List<CartItem>) onAddToCartToTable;
  final List<int> Function() getActiveTableIds;

  const PosPage({
    super.key,
    required this.currentUser,
    required this.onAddToCartToTable,
    required this.getActiveTableIds,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final List<CartItem> _cart = [];
  LocalMember? _selectedMember;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Menampilkan dialog untuk memilih varian produk dan menambahkan catatan.
  Future<void> _showVariantSelectionDialog(LocalProduct product) async {
    ProductVariant? selectedVariant =
        product.variants.isNotEmpty ? product.variants.first : null;
    final noteController = TextEditingController();

    final result = await showDialog<CartItem>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2c2c2c),
              title: Text('Pilih Opsi untuk ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Varian:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...product.variants.map((variant) {
                      return RadioListTile<ProductVariant>(
                        title: Text(variant.name),
                        subtitle: Text(_currencyFormat.format(variant.price)),
                        value: variant,
                        groupValue: selectedVariant,
                        onChanged: (value) {
                          setStateInDialog(() => selectedVariant = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        hintText: 'Contoh: Gula 1 sendok',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                ElevatedButton(
                  onPressed: selectedVariant == null
                      ? null
                      : () {
                          final newItem = CartItem(
                            product: product,
                            selectedVariant: selectedVariant,
                            note: noteController.text.trim().isNotEmpty
                                ? noteController.text.trim()
                                : null,
                          );
                          Navigator.pop(context, newItem);
                        },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _handleAddToCart(result);
    }
  }

  /// Mengelola penambahan item ke keranjang.
  void _handleAddToCart(dynamic itemOrProduct) {
    setState(() {
      if (itemOrProduct is CartItem) {
        _cart.add(itemOrProduct);
      } else if (itemOrProduct is LocalProduct) {
        final product = itemOrProduct;
        if (product.stock <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stok ${product.name} habis.')));
          return;
        }

        final index = _cart.indexWhere((item) =>
            (item.product as LocalProduct).key == product.key &&
            item.selectedVariant == null &&
            item.note == null);

        if (index != -1) {
          if (_cart[index].quantity < product.stock) {
            _cart[index].quantity++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Stok ${product.name} tidak mencukupi.')));
          }
        } else {
          _cart.add(CartItem(product: product));
        }
      }
    });
  }

  void _updateQuantity(CartItem item, int change) {
    setState(() {
      final product = item.product as LocalProduct;
      final newQuantity = item.quantity + change;
      if (newQuantity <= 0) {
        _cart.remove(item);
      } else if (newQuantity <= product.stock) {
        item.quantity = newQuantity;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok ${product.name} tidak mencukupi.')),
        );
      }
    });
  }

  double get _subtotal {
    return _cart.fold(0, (sum, item) {
      final price = item.selectedVariant?.price ??
          (item.product as LocalProduct).sellingPrice;
      return sum + (price * item.quantity);
    });
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

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedMember = null;
    });
  }

  Future<void> _showAddToTableDialog() async {
    final activeTables = widget.getActiveTableIds();
    if (activeTables.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak ada meja yang sedang aktif.'),
        backgroundColor: Colors.orangeAccent,
      ));
      return;
    }

    final selectedTable = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          title: const Text('Pilih Meja'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: activeTables.length,
              itemBuilder: (context, index) {
                final tableId = activeTables[index];
                return ListTile(
                  title: Text('Meja $tableId'),
                  onTap: () => Navigator.of(context).pop(tableId),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedTable != null) {
      widget.onAddToCartToTable(selectedTable, List<CartItem>.from(_cart));
      _clearCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Item berhasil ditambahkan ke tagihan Meja $selectedTable!'),
          backgroundColor: Colors.blueAccent,
        ));
      }
    }
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keranjang masih kosong!')));
      return;
    }

    String selectedPaymentMethod = 'Cash';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateInDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2c2c2c),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Konfirmasi Transaksi'),
            content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subtotal: ${_currencyFormat.format(_subtotal)}'),
                    if (_discountAmount > 0)
                      Text(
                          'Diskon: - ${_currencyFormat.format(_discountAmount)}'),
                    Text('Total: ${_currencyFormat.format(_totalPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        'Atas nama: ${_selectedMember?.name ?? "Pelanggan Umum"}'),
                    const Divider(height: 24, color: Colors.white24),
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
                          final allOptions =
                              {'Cash', ...paymentMethods}.toList();
                          return DropdownButton<String>(
                            value: selectedPaymentMethod,
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
                                setStateInDialog(
                                    () => selectedPaymentMethod = newValue);
                              }
                            },
                          );
                        })
                  ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Bayar')),
            ],
          );
        });
      },
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final now = DateTime.now();
        final localTransaction = LocalTransaction(
          flow: 'income',
          type: 'pos',
          totalAmount: _totalPrice,
          createdAt: now,
          cashierId: widget.currentUser.uid,
          cashierName: widget.currentUser.nama,
          subtotal: _subtotal,
          discount: _discountAmount,
          memberId: _selectedMember?.key.toString(),
          memberName: _selectedMember?.name,
          paymentMethod: selectedPaymentMethod,
          items: _cart.map((item) {
            final product = item.product as LocalProduct;
            return {
              'productId': product.key.toString(),
              'productName': product.name,
              'quantity': item.quantity,
              'price': item.selectedVariant?.price ?? product.sellingPrice,
              'variantName': item.selectedVariant?.name,
              'note': item.note,
            };
          }).toList(),
        );

        await _localDbService.addTransaction(localTransaction);

        for (var item in _cart) {
          final product = item.product as LocalProduct;
          final stockBefore = product.stock;
          final mutation = LocalStockMutation(
              productId: product.key.toString(),
              productName: product.name,
              type: 'sale',
              quantityChange: -item.quantity,
              stockBefore: stockBefore,
              notes: 'POS Transaksi',
              date: now,
              userId: widget.currentUser.uid,
              userName: widget.currentUser.nama);
          await _localDbService.addStockMutation(mutation);
          await _localDbService.decreaseStockForSale(
              product.key, item.quantity);
        }
        _clearCart();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaksi berhasil disimpan (Lokal)!'),
          backgroundColor: Colors.green,
        ));
      } catch (e, s) {
        print('Error during checkout: $e\n$s');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Terjadi error: $e'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ValueListenableBuilder<Box<LocalProduct>>(
        valueListenable: _localDbService.getProductListenable(),
        builder: (context, box, _) {
          final products =
              box.values.where((p) => p.isActive).toList().cast<LocalProduct>();
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
                onTap: () {
                  if (product.hasVariants) {
                    _showVariantSelectionDialog(product);
                  } else {
                    _handleAddToCart(product);
                  }
                },
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
                                        : Colors.grey[400],
                                    fontSize: 12)),
                            Text(
                                product.hasVariants &&
                                        product.variants.isNotEmpty
                                    ? 'Mulai dari ${_currencyFormat.format(product.variants.first.price)}'
                                    : _currencyFormat
                                        .format(product.sellingPrice),
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
      margin: const EdgeInsets.all(8.0),
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
      child: ValueListenableBuilder<Box<LocalMember>>(
        valueListenable: _localDbService.getMemberListenable(),
        builder: (context, box, _) {
          final members = box.values.toList().cast<LocalMember>();
          List<DropdownMenuItem<LocalMember?>> items = [
            const DropdownMenuItem<LocalMember?>(
                value: null, child: Text('Pelanggan Umum')),
            ...members.where((m) => m.isActive).map((member) {
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
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2c2c2c),
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
          const Divider(height: 24, color: Colors.white24),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Keranjang kosong'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      final product = item.product as LocalProduct;
                      final price =
                          item.selectedVariant?.price ?? product.sellingPrice;

                      String title = product.name;
                      if (item.selectedVariant != null) {
                        title += ' (${item.selectedVariant!.name})';
                      }

                      List<Widget> subtitleWidgets = [
                        Text(_currencyFormat.format(price * item.quantity))
                      ];
                      if (item.note != null && item.note!.isNotEmpty) {
                        subtitleWidgets.add(Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text('Catatan: ${item.note!}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey)),
                        ));
                      }

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: subtitleWidgets,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20, color: Colors.amber),
                              onPressed: () => _updateQuantity(item, -1),
                            ),
                            Text(item.quantity.toString(),
                                style: const TextStyle(fontSize: 16)),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20, color: Colors.cyanAccent),
                              onPressed: () => _updateQuantity(item, 1),
                            ),
                            IconButton(
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
          const Divider(color: Colors.white24),
          _buildPriceRow('Total:', _totalPrice, isTotal: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cart.isNotEmpty ? _checkout : null,
              icon: const Icon(Icons.payment),
              label: const Text('Bayar Langsung'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cart.isNotEmpty ? _showAddToTableDialog : null,
              icon: const Icon(Icons.add_to_photos_rounded),
              label: const Text('Tambah ke Tagihan Meja'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
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
