import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:putra_jaya_billiard/models/billing_transaction.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Nama koleksi baru yang terunifikasi
  final String _unifiedTransactionsCollection = 'unified_transactions';

  // --- Unified Transaction Methods ---

  // CATATAN: Method ini diubah. Sekarang membutuhkan 'cashier' (UserModel).
  // Sesuaikan pemanggilan method ini di halaman dashboard Anda.
  Future<void> saveBillingTransaction(
      BillingTransaction transaction, UserModel cashier) async {
    final transactionData = transaction.toMap();

    // Menambahkan field standar untuk unifikasi
    transactionData['type'] = 'billiard';
    transactionData['createdAt'] = transaction.startTime;
    transactionData['totalAmount'] = transaction.totalCost;
    transactionData['cashierId'] = cashier.uid;
    transactionData['cashierName'] = cashier.nama;

    // Simpan ke koleksi terunifikasi
    await _db.collection(_unifiedTransactionsCollection).add(transactionData);
  }

  // Mengambil SEMUA jenis transaksi (Billiard & POS)
  Stream<QuerySnapshot> getTransactionsStream() {
    return _db
        .collection(_unifiedTransactionsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteTransaction(String docId) async {
    await _db.collection(_unifiedTransactionsCollection).doc(docId).delete();
  }

  // Laporan pendapatan dari SEMUA jenis transaksi
  Stream<QuerySnapshot> getReportStream(DateTime start, DateTime end) {
    return _db
        .collection(_unifiedTransactionsCollection)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Product Methods ---

  Stream<List<Product>> getProductsStream() {
    return _db.collection('products').orderBy('name').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  Future<void> addProduct(Product product) async {
    await _db.collection('products').add(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) return;
    await _db.collection('products').doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  // --- POS Methods ---

  Future<void> saveSalesTransactionAndDecreaseStock(
      List<CartItem> cartItems, UserModel cashier) async {
    if (cartItems.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final salesDocRef = _db.collection(_unifiedTransactionsCollection).doc();

    double totalAmount = 0;
    List<Map<String, dynamic>> itemsForTransaction = [];

    for (var item in cartItems) {
      totalAmount += item.product.sellingPrice * item.quantity;
      itemsForTransaction.add({
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': item.quantity,
        'price': item.product.sellingPrice,
      });

      final productDocRef = _db.collection('products').doc(item.product.id!);
      batch.update(
          productDocRef, {'stock': FieldValue.increment(-item.quantity)});
    }

    // Membuat map transaksi POS dengan field standar
    final transactionData = {
      'items': itemsForTransaction,
      'totalAmount': totalAmount,
      'cashierId': cashier.uid,
      'cashierName': cashier.nama,
      // Field standar untuk unifikasi
      'type': 'pos',
      'createdAt': DateTime.now(),
    };

    batch.set(salesDocRef, transactionData);

    await batch.commit();
  }
}
