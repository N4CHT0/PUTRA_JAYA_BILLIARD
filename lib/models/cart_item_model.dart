import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart'; // 1. Impor model varian

class CartItem {
  final LocalProduct product;
  int quantity;

  // 2. Tambahkan field untuk varian dan catatan
  ProductVariant? selectedVariant;
  String? note;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedVariant, // 3. Tambahkan di constructor
    this.note, // 3. Tambahkan di constructor
  });

  // 4. Perbarui method untuk menyertakan data baru saat disimpan
  Map<String, dynamic> toMapForTransaction() {
    return {
      'productId': product.key.toString(),
      'productName': product.name,
      'quantity': quantity,
      // Gunakan harga varian jika ada, jika tidak, gunakan harga dasar produk
      'price': selectedVariant?.sellingPrice ?? 0,
      'variantName': selectedVariant?.name, // Simpan nama varian
      'note': note, // Simpan catatan
    };
  }
}
