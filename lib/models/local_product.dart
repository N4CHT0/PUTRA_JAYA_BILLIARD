// lib/models/local_product.dart

import 'package:hive/hive.dart';
import 'product_variant.dart';

part 'local_product.g.dart';

@HiveType(typeId: 1)
class LocalProduct extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name; // Contoh: "Kopi", "Mie Instan"

  @HiveField(2)
  String unit; // DIKEMBALIKAN KE SINI. Contoh: "gelas", "porsi"

  @HiveField(3)
  bool isActive;

  @HiveField(4)
  List<ProductVariant> variants;

  LocalProduct({
    this.id,
    required this.name,
    required this.unit, // Tambahkan di constructor
    this.isActive = true,
    this.variants = const [],
  });

  bool get hasVariants => variants.isNotEmpty;

  int get totalStock => variants.fold(0, (sum, variant) => sum + variant.stock);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit, // Tambahkan ke toJson
        'isActive': isActive,
        'variants': variants.map((v) => v.toJson()).toList(),
      };

  factory LocalProduct.fromJson(Map<String, dynamic> json) => LocalProduct(
        id: json['id'],
        name: json['name'],
        unit: json['unit'], // Tambahkan ke fromJson
        isActive: json['isActive'],
        variants: (json['variants'] as List<dynamic>?)
                ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
