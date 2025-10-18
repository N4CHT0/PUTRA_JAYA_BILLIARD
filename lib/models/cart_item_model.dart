// lib/models/cart_item_model.dart
import 'package:putra_jaya_billiard/models/local_product.dart'; // PASTIKAN IMPORT INI

class CartItem {
  final LocalProduct product; // PASTIKAN TIPE INI
  int quantity;

  CartItem(
      {required this.product, // PASTIKAN MENERIMA LocalProduct
      this.quantity = 1});

  Map<String, dynamic> toMapForTransaction() {
    return {
      'productId': product.key.toString(),
      'productName': product.name,
      'quantity': quantity,
      'price': product.sellingPrice,
    };
  }
}
