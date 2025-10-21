// lib/models/purchase_item_model.dart
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';

// Model ini digunakan sementara di halaman UI untuk mengelola daftar item pembelian
class PurchaseItem {
  final LocalProduct product;
  final ProductVariant
      variant; // 2. Tambahkan field untuk menyimpan varian yang dibeli
  int quantity;
  double purchasePrice; // Harga beli bisa diubah saat transaksi

  PurchaseItem({
    required this.product,
    required this.variant, // 3. Jadikan varian sebagai parameter wajib
    required this.quantity,
    required this.purchasePrice,
  });
}
