// Model ini yang akan disimpan ke Firestore sebagai catatan transaksi pembelian
class PurchaseTransaction {
  final String? id;
  final String supplierId;
  final String supplierName;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final DateTime transactionDate;
  final String userId; // Siapa yang mencatat transaksi

  PurchaseTransaction({
    this.id,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.transactionDate,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items,
      'totalAmount': totalAmount,
      'transactionDate': transactionDate,
      'userId': userId,
    };
  }
}
