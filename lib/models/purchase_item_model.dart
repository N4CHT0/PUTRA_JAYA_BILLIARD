// lib/models/purchase_item_model.dart

// --- PERUBAHAN 1: Import model LOKAL ---
import 'package:putra_jaya_billiard/models/local_product.dart';

// Model ini digunakan sementara di halaman UI untuk mengelola daftar item pembelian
class PurchaseItem {
  // --- PERUBAHAN 2: Ganti tipe data product ---
  final LocalProduct product;
  int quantity;
  double purchasePrice; // Harga beli bisa diubah saat transaksi

  PurchaseItem({
    required this.product, // Sekarang menerima LocalProduct
    this.quantity = 1,
    required this.purchasePrice,
  });

  // Anda bisa menambahkan metode toMap() jika diperlukan
  // Map<String, dynamic> toMapForTransaction() {
  //   return {
  //     'productId': product.key.toString(), // Gunakan key Hive
  //     'productName': product.name,
  //     'quantity': quantity,
  //     'purchasePrice': purchasePrice,
  //   };
  // }
}
