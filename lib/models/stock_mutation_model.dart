import 'package:cloud_firestore/cloud_firestore.dart';

enum MutationType { sale, purchase, adjustment }

class StockMutation {
  final String? id;
  final String productId;
  final String productName;
  final MutationType type; // 'sale', 'purchase', 'adjustment'
  final int quantityChange; // Negatif untuk keluar, Positif untuk masuk
  final int stockBefore;
  final int stockAfter;
  final String notes; // e.g., "POS-TRX123", "PUR-SUP456", "Stok Opname"
  final DateTime date;
  final String userId;
  final String userName;

  StockMutation({
    this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantityChange,
    required this.stockBefore,
    required this.notes,
    required this.date,
    required this.userId,
    required this.userName,
  }) : stockAfter = stockBefore + quantityChange;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'type':
          type.name, // Simpan sebagai string: 'sale', 'purchase', 'adjustment'
      'quantityChange': quantityChange,
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
      'notes': notes,
      'date': date,
      'userId': userId,
      'userName': userName,
    };
  }

  factory StockMutation.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return StockMutation(
      id: doc.id,
      productId: data['productId'],
      productName: data['productName'],
      type: MutationType.values.firstWhere((e) => e.name == data['type']),
      quantityChange: data['quantityChange'],
      stockBefore: data['stockBefore'],
      notes: data['notes'],
      date: (data['date'] as Timestamp).toDate(),
      userId: data['userId'],
      userName: data['userName'],
    );
  }
}
