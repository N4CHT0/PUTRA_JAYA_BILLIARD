// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:putra_jaya_billiard/models/billing_transaction.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/product_model.dart';
import 'package:putra_jaya_billiard/models/purchase_item_model.dart';
import 'package:putra_jaya_billiard/models/stock_adjustment_model.dart';
import 'package:putra_jaya_billiard/models/stock_mutation_model.dart';
import 'package:putra_jaya_billiard/models/supplier_model.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _financialTransactionsCollection = 'financial_transactions';

  // --- Financial Transaction Methods ---

  // Metode ini tidak perlu diubah karena tidak menggunakan batch/transaction
  Future<void> saveBillingTransaction(
      BillingTransaction transaction, UserModel cashier) async {
    final transactionData = transaction.toMap();
    transactionData['flow'] = 'income';
    transactionData['type'] = 'billiard';
    transactionData['createdAt'] = transaction.startTime;
    transactionData['totalAmount'] = transaction.totalCost;
    transactionData['cashierId'] = cashier.uid;
    transactionData['cashierName'] = cashier.nama;
    await _db.collection(_financialTransactionsCollection).add(transactionData);
  }

  // --- FUNGSI DIPERBARUI: Menggunakan WriteBatch untuk stabilitas ---
  Future<void> saveSalesTransactionAndDecreaseStock(
      List<CartItem> cartItems, UserModel cashier) async {
    if (cartItems.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final salesDocRef = _db.collection(_financialTransactionsCollection).doc();
    double totalAmount = 0;
    List<Map<String, dynamic>> itemsForTransaction = [];

    for (var item in cartItems) {
      final productDocRef = _db.collection('products').doc(item.product.id!);

      // 1. Siapkan perintah untuk mengurangi stok
      batch.update(
          productDocRef, {'stock': FieldValue.increment(-item.quantity)});

      // 2. Siapkan catatan mutasi
      final mutation = StockMutation(
        productId: item.product.id!,
        productName: item.product.name,
        type: MutationType.sale,
        quantityChange: -item.quantity,
        stockBefore: item.product.stock,
        notes: 'POS Transaksi #${salesDocRef.id.substring(0, 6)}',
        date: DateTime.now(),
        userId: cashier.uid,
        userName: cashier.nama,
      );
      final mutationDocRef = _db.collection('stock_mutations').doc();
      batch.set(mutationDocRef, mutation.toMap());

      // 3. Kumpulkan data untuk catatan keuangan
      totalAmount += item.product.sellingPrice * item.quantity;
      itemsForTransaction.add({
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': item.quantity,
        'price': item.product.sellingPrice,
      });
    }

    // 4. Siapkan catatan transaksi keuangan
    final financialTransactionData = {
      'flow': 'income',
      'type': 'pos',
      'items': itemsForTransaction,
      'totalAmount': totalAmount,
      'cashierId': cashier.uid,
      'cashierName': cashier.nama,
      'createdAt': DateTime.now(),
    };
    batch.set(salesDocRef, financialTransactionData);

    // 5. Jalankan semua operasi sekaligus
    await batch.commit();
  }

  // --- FUNGSI DIPERBARUI: Menggunakan WriteBatch untuk stabilitas ---
  Future<void> savePurchaseAndUpdateStock(List<PurchaseItem> purchaseItems,
      Supplier supplier, UserModel user) async {
    if (purchaseItems.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final purchaseDocRef =
        _db.collection(_financialTransactionsCollection).doc();
    double totalAmount = 0;
    List<Map<String, dynamic>> itemsForTransaction = [];

    for (var item in purchaseItems) {
      final productDocRef = _db.collection('products').doc(item.product.id!);

      batch.update(productDocRef, {
        'stock': FieldValue.increment(item.quantity),
        'purchasePrice': item.purchasePrice,
      });

      final mutation = StockMutation(
        productId: item.product.id!,
        productName: item.product.name,
        type: MutationType.purchase,
        quantityChange: item.quantity,
        stockBefore: item.product.stock,
        notes: 'Pembelian dari ${supplier.name}',
        date: DateTime.now(),
        userId: user.uid,
        userName: user.nama,
      );
      final mutationDocRef = _db.collection('stock_mutations').doc();
      batch.set(mutationDocRef, mutation.toMap());

      totalAmount += item.purchasePrice * item.quantity;
      itemsForTransaction.add({
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': item.quantity,
        'purchasePrice': item.purchasePrice,
      });
    }

    final financialTransactionData = {
      'flow': 'expense',
      'type': 'purchase',
      'supplierId': supplier.id,
      'supplierName': supplier.name,
      'items': itemsForTransaction,
      'totalAmount': totalAmount,
      'userId': user.uid,
      'userName': user.nama,
      'createdAt': DateTime.now(),
    };
    batch.set(purchaseDocRef, financialTransactionData);

    await batch.commit();
  }

  // --- FUNGSI DIPERBARUI: Menggunakan WriteBatch untuk stabilitas ---
  Future<void> performStockAdjustment(
      List<StockAdjustment> adjustments, UserModel user) async {
    if (adjustments.isEmpty) return;

    final WriteBatch batch = _db.batch();

    for (var adj in adjustments) {
      final productDocRef = _db.collection('products').doc(adj.productId);
      batch.update(productDocRef, {'stock': adj.newStock});

      final mutation = StockMutation(
        productId: adj.productId,
        productName: adj.productName,
        type: MutationType.adjustment,
        quantityChange: adj.difference,
        stockBefore: adj.previousStock,
        notes: adj.reason,
        date: DateTime.now(),
        userId: user.uid,
        userName: user.nama,
      );
      final mutationDocRef = _db.collection('stock_mutations').doc();
      batch.set(mutationDocRef, mutation.toMap());
    }

    await batch.commit();
  }

  // --- Read Methods (Tidak Berubah) ---
  Stream<QuerySnapshot> getFinancialTransactionsStream() {
    return _db
        .collection(_financialTransactionsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteFinancialTransaction(String docId) {
    return _db.collection(_financialTransactionsCollection).doc(docId).delete();
  }

  Stream<QuerySnapshot> getFinancialReportStream(DateTime start, DateTime end) {
    return _db
        .collection(_financialTransactionsCollection)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<List<StockMutation>> getStockMutationsStream(String productId) {
    return _db
        .collection('stock_mutations')
        .where('productId', isEqualTo: productId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockMutation.fromFirestore(doc))
            .toList());
  }

  // --- Product Methods (Tidak Berubah) ---
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

  // --- Supplier Methods (Tidak Berubah) ---
  Stream<List<Supplier>> getSuppliersStream() {
    return _db.collection('suppliers').orderBy('name').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Supplier.fromFirestore(doc)).toList());
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _db.collection('suppliers').add(supplier.toMap());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    if (supplier.id == null) return;
    await _db.collection('suppliers').doc(supplier.id).update(supplier.toMap());
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _db.collection('suppliers').doc(supplierId).delete();
  }
}
