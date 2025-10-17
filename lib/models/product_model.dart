// lib/models/product_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String name;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final bool isActive;

  Product({
    this.id,
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.isActive = true,
  });

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

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'pcs',
      purchasePrice: (data['purchasePrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  // --- BAGIAN PALING PENTING UNTUK MEMPERBAIKI ERROR ---
  // Override operator '==' dan hashCode untuk perbandingan objek yang benar.
  // Ini memberitahu Dart untuk menganggap dua objek Product sama jika ID-nya sama.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
