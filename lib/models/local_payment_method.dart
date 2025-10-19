// lib/models/local_payment_method.dart

import 'package:hive/hive.dart';

part 'local_payment_method.g.dart';

@HiveType(typeId: 6) // Gunakan ID Tipe yang belum terpakai
class LocalPaymentMethod extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  bool isActive;

  LocalPaymentMethod({
    required this.name,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
      };

  factory LocalPaymentMethod.fromJson(Map<String, dynamic> json) =>
      LocalPaymentMethod(
        name: json['name'],
        isActive: json['isActive'],
      );
}
