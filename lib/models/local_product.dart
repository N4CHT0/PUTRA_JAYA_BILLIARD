import 'package:hive/hive.dart';
import 'product_variant.dart'; // 1. Impor model baru

part 'local_product.g.dart';

@HiveType(typeId: 1)
class LocalProduct extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String unit;

  @HiveField(3)
  double purchasePrice;

  @HiveField(4)
  double sellingPrice; // Anggap ini sebagai harga dasar jika tidak ada varian

  @HiveField(5)
  int stock;

  @HiveField(6)
  bool isActive;

  // 2. Tambahkan field baru untuk varian
  @HiveField(7)
  List<ProductVariant> variants;

  LocalProduct({
    this.id,
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.isActive = true,
    this.variants = const [], // 3. Tambahkan di constructor
  });

  // 4. Getter untuk kemudahan pengecekan
  bool get hasVariants => variants.isNotEmpty;

  // 5. Perbarui method toJson dan fromJson
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'stock': stock,
        'isActive': isActive,
        'variants': variants.map((v) => v.toJson()).toList(), // Sertakan varian
      };

  factory LocalProduct.fromJson(Map<String, dynamic> json) => LocalProduct(
        id: json['id'],
        name: json['name'],
        unit: json['unit'],
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        sellingPrice: (json['sellingPrice'] as num).toDouble(),
        stock: json['stock'],
        isActive: json['isActive'],
        // Ambil data varian dari JSON, jika tidak ada, gunakan list kosong
        variants: (json['variants'] as List<dynamic>?)
                ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
