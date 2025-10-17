import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String name;
  final String unit; // Diubah dari 'category' menjadi 'unit' (satuan)
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final bool isActive; // Ditambahkan untuk status 'Non Aktif'

  Product({
    this.id,
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.isActive = true, // Default produk aktif saat dibuat
  });

  // Mengubah Product object menjadi Map untuk disimpan di Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'stock': stock,
      'isActive': isActive,
    };
  }

  // Membuat Product object dari Firestore DocumentSnapshot
  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'pcs', // Menggunakan 'unit'
      purchasePrice: (data['purchasePrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      isActive: data['isActive'] ?? true, // Membaca status 'isActive'
    );
  }
}
