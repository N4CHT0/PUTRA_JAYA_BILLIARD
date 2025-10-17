import 'package:cloud_firestore/cloud_firestore.dart';

class StockAdjustment {
  final String? id;
  final String productId;
  final String productName;
  final int previousStock;
  final int newStock;
  final int difference; // Selisih (bisa positif atau negatif)
  final String reason; // Alasan penyesuaian (e.g., Stok Opname, Rusak)
  final String userId;
  final String userName;
  final DateTime adjustmentDate;

  StockAdjustment({
    this.id,
    required this.productId,
    required this.productName,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    required this.userId,
    required this.userName,
    required this.adjustmentDate,
  }) : difference = newStock - previousStock;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'previousStock': previousStock,
      'newStock': newStock,
      'difference': difference,
      'reason': reason,
      'userId': userId,
      'userName': userName,
      'adjustmentDate': adjustmentDate,
    };
  }
}
