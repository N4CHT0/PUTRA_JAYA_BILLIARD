// lib/models/local_member.dart
import 'package:hive/hive.dart';

part 'local_member.g.dart'; // Akan digenerate

@HiveType(typeId: 2) // ID Tipe unik
class LocalMember extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String address;

  @HiveField(3)
  String phone;

  @HiveField(4)
  DateTime joinDate; // Gunakan DateTime

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  double discountPercentage;

  LocalMember({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.joinDate,
    this.isActive = true,
    this.discountPercentage = 0,
  });

  // Method untuk mengubah objek menjadi Map (JSON)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'joinDate': joinDate.toIso8601String(),
        'isActive': isActive,
        'discountPercentage': discountPercentage,
      };

  // Factory constructor untuk membuat objek dari Map (JSON)
  factory LocalMember.fromJson(Map<String, dynamic> json) => LocalMember(
        id: json['id'],
        name: json['name'],
        address: json['address'],
        phone: json['phone'],
        joinDate: DateTime.parse(json['joinDate']),
        isActive: json['isActive'],
        discountPercentage: json['discountPercentage'],
      );
}
