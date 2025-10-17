import 'package:putra_jaya_billiard/models/product_model.dart';

// Model ini digunakan sementara di halaman UI untuk mengelola daftar item pembelian
class PurchaseItem {
  final Product product;
  int quantity;
  double purchasePrice; // Harga beli bisa diubah saat transaksi

  PurchaseItem({
    required this.product,
    this.quantity = 1,
    required this.purchasePrice,
  });
}
