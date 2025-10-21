// lib/models/product_variant.dart

import 'package:hive/hive.dart';

part 'product_variant.g.dart';

@HiveType(typeId: 10)
class ProductVariant extends HiveObject {
  @HiveField(0)
  String name; // Contoh: "Susu", "Gula Aren"

  @HiveField(1)
  double purchasePrice;

  @HiveField(2)
  double sellingPrice;

  @HiveField(3)
  int stock;

  // FIELD 'unit' DIHAPUS DARI SINI

  ProductVariant({
    required this.name,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'stock': stock,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        name: json['name'],
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        sellingPrice: (json['sellingPrice'] as num).toDouble(),
        stock: json['stock'],
      );
}
