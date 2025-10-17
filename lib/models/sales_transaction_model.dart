import 'package:cloud_firestore/cloud_firestore.dart';

class SalesTransaction {
  final String? id;
  final List<Map<String, dynamic>> items; // List produk yg terjual
  final double totalAmount;
  final DateTime transactionTime;
  final String cashierId; // ID pengguna yang melakukan transaksi
  final String cashierName; // Nama pengguna

  SalesTransaction({
    this.id,
    required this.items,
    required this.totalAmount,
    required this.transactionTime,
    required this.cashierId,
    required this.cashierName,
  });

  Map<String, dynamic> toMap() {
    return {
      'items': items,
      'totalAmount': totalAmount,
      'transactionTime': transactionTime,
      'cashierId': cashierId,
      'cashierName': cashierName,
    };
  }
}
