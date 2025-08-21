import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:putra_jaya_billiard/models/billing_transaction.dart';

class FirebaseService {
  final CollectionReference _transactions = FirebaseFirestore.instance
      .collection('transactions');

  Future<void> saveTransaction(BillingTransaction transaction) async {
    await _transactions.add(transaction.toMap());
  }

  Stream<QuerySnapshot> getTransactionsStream() {
    return _transactions.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> deleteTransaction(String docId) async {
    await _transactions.doc(docId).delete();
  }

  Stream<QuerySnapshot> getReportStream(DateTime start, DateTime end) {
    return _transactions
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
