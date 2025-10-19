import 'package:hive/hive.dart';

part 'product_variant.g.dart'; // Akan digenerate oleh build_runner

// Ganti typeId jika 10 sudah terpakai di model Hive Anda yang lain
@HiveType(typeId: 10)
class ProductVariant extends HiveObject {
  @HiveField(0)
  late String name; // Contoh: "Double Shot", "Less Sugar"

  @HiveField(1)
  late double price; // Harga untuk varian ini (bukan selisih harga)

  ProductVariant({required this.name, required this.price});

  // Method konversi (opsional tapi praktik yang baik)
  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        name: json['name'],
        price: (json['price'] as num).toDouble(),
      );
}
