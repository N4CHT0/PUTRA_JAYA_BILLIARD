// lib/models/local_supplier.dart
import 'package:hive/hive.dart';

part 'local_supplier.g.dart'; // Akan digenerate

@HiveType(typeId: 3) // ID Tipe unik
class LocalSupplier extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String address;

  @HiveField(3)
  String phone;

  @HiveField(4)
  bool isActive;

  LocalSupplier({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.isActive = true,
  });

  // Method untuk mengubah objek menjadi Map (JSON)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'isActive': isActive,
      };

  // Factory constructor untuk membuat objek dari Map (JSON)
  factory LocalSupplier.fromJson(Map<String, dynamic> json) => LocalSupplier(
        id: json['id'],
        name: json['name'],
        address: json['address'],
        phone: json['phone'],
        isActive: json['isActive'],
      );
}
