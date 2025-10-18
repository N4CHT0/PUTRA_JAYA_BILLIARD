// lib/models/local_stock_mutation.dart

import 'package:hive/hive.dart';

part 'local_stock_mutation.g.dart'; // Akan digenerate

@HiveType(typeId: 5) // ID Tipe unik
class LocalStockMutation extends HiveObject {
  @HiveField(0)
  String productId;

  @HiveField(1)
  String productName;

  @HiveField(2)
  String type; // Tipe mutasi ('sale', 'purchase', 'adjustment')

  @HiveField(3)
  int quantityChange; // Negatif jika keluar

  @HiveField(4)
  int stockBefore;

  @HiveField(5)
  String notes;

  @HiveField(6)
  DateTime date;

  @HiveField(7)
  String userId;

  @HiveField(8)
  String userName;

  int get stockAfter => stockBefore + quantityChange;

  LocalStockMutation({
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantityChange,
    required this.stockBefore,
    required this.notes,
    required this.date,
    required this.userId,
    required this.userName,
  });

  // Method untuk mengubah objek menjadi Map (JSON)
  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'type': type,
        'quantityChange': quantityChange,
        'stockBefore': stockBefore,
        'notes': notes,
        'date': date.toIso8601String(),
        'userId': userId,
        'userName': userName,
      };

  // Factory constructor untuk membuat objek dari Map (JSON)
  factory LocalStockMutation.fromJson(Map<String, dynamic> json) =>
      LocalStockMutation(
        productId: json['productId'],
        productName: json['productName'],
        type: json['type'],
        quantityChange: json['quantityChange'],
        stockBefore: json['stockBefore'],
        notes: json['notes'],
        date: DateTime.parse(json['date']),
        userId: json['userId'],
        userName: json['userName'],
      );
}
