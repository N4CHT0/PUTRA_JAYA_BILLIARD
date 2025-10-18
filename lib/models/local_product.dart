// lib/models/local_product.dart
import 'package:hive/hive.dart';

part 'local_product.g.dart'; // File ini akan digenerate

@HiveType(typeId: 1) // ID Tipe harus unik per model
class LocalProduct extends HiveObject {
  // Wajib extend HiveObject

  @HiveField(0) // Index field unik per model
  String? id; // ID bisa dibuat manual atau otomatis oleh Hive

  @HiveField(1)
  String name;

  @HiveField(2)
  String unit;

  @HiveField(3)
  double purchasePrice;

  @HiveField(4)
  double sellingPrice;

  @HiveField(5)
  int stock;

  @HiveField(6)
  bool isActive;

  // Constructor
  LocalProduct({
    this.id, // ID bisa jadi opsional jika key di-handle Hive
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.isActive = true,
  });

  // Method untuk mengubah objek menjadi Map (JSON)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'stock': stock,
        'isActive': isActive,
      };

  // Factory constructor untuk membuat objek dari Map (JSON)
  factory LocalProduct.fromJson(Map<String, dynamic> json) => LocalProduct(
        id: json['id'],
        name: json['name'],
        unit: json['unit'],
        purchasePrice: json['purchasePrice'],
        sellingPrice: json['sellingPrice'],
        stock: json['stock'],
        isActive: json['isActive'],
      );
}
