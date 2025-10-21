// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:putra_jaya_billiard/models/billing_transaction.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/member_model.dart';
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

  Future<void> saveBillingTransaction(
      BillingTransaction transaction, UserModel cashier,
      {Member? member,
      required double subtotal,
      required double discount,
      required double finalTotal}) async {
    final transactionData = transaction.toMap();
    transactionData['flow'] = 'income';
    transactionData['type'] = 'billiard';
    transactionData['createdAt'] = transaction.startTime;
    transactionData['subtotal'] = subtotal;
    transactionData['discount'] = discount;
    transactionData['totalAmount'] = finalTotal;
    transactionData['cashierId'] = cashier.uid;
    transactionData['cashierName'] = cashier.nama;
    if (member != null) {
      transactionData['memberId'] = member.id;
      transactionData['memberName'] = member.name;
    }
    await _db.collection(_financialTransactionsCollection).add(transactionData);
  }

  Future<void> saveSalesTransactionAndDecreaseStock(
      List<CartItem> cartItems, UserModel cashier,
      {Member? member,
      required double subtotal,
      required double discount,
      required double finalTotal}) async {
    if (cartItems.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final salesDocRef = _db.collection(_financialTransactionsCollection).doc();

    for (var item in cartItems) {
      if (item.product.id == null || item.selectedVariant == null) continue;

      _db.collection('products').doc(item.product.id!);
      final selectedVariant = item.selectedVariant!;

      // WARNING: Firestore array updates are complex. This section is for mutation logging only.
      // Stock updates on Firebase would require a get-then-set operation, ideally in a Cloud Function.
      /*
      batch.update(
          productDocRef, {'stock': FieldValue.increment(-item.quantity)});
      */

      final mutation = StockMutation(
        productId: item.product.id!,
        productName: '${item.product.name} (${selectedVariant.name})',
        type: MutationType.sale,
        quantityChange: -item.quantity,
        stockBefore: selectedVariant.stock,
        notes: 'POS Transaksi #${salesDocRef.id.substring(0, 6)}',
        date: DateTime.now(),
        userId: cashier.uid,
        userName: cashier.nama,
      );
      final mutationDocRef = _db.collection('stock_mutations').doc();
      batch.set(mutationDocRef, mutation.toMap());
    }

    final Map<String, dynamic> financialTransactionData = {
      'flow': 'income',
      'type': 'pos',
      'items': cartItems.map((item) => item.toMapForTransaction()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'totalAmount': finalTotal,
      'cashierId': cashier.uid,
      'cashierName': cashier.nama,
      'createdAt': DateTime.now(),
    };
    if (member != null) {
      financialTransactionData['memberId'] = member.id;
      financialTransactionData['memberName'] = member.name;
    }
    batch.set(salesDocRef, financialTransactionData);

    await batch.commit();
  }

  Future<void> savePurchaseAndUpdateStock(List<PurchaseItem> purchaseItems,
      Supplier supplier, UserModel user) async {
    if (purchaseItems.isEmpty) return;

    final WriteBatch batch = _db.batch();
    final purchaseDocRef =
        _db.collection(_financialTransactionsCollection).doc();
    double totalAmount = 0;

    for (var item in purchaseItems) {
      if (item.product.id == null) continue;

      _db.collection('products').doc(item.product.id!);
      final variant = item.variant;

      // WARNING: Firestore array updates are complex. This section is for mutation logging only.
      /*
      batch.update(productDocRef, {
        'stock': FieldValue.increment(item.quantity),
        'purchasePrice': item.purchasePrice,
      });
      */

      final mutation = StockMutation(
        productId: item.product.id!,
        productName: '${item.product.name} (${variant.name})',
        type: MutationType.purchase,
        quantityChange: item.quantity,
        stockBefore: variant.stock,
        notes: 'Pembelian dari ${supplier.name}',
        date: DateTime.now(),
        userId: user.uid,
        userName: user.nama,
      );
      final mutationDocRef = _db.collection('stock_mutations').doc();
      batch.set(mutationDocRef, mutation.toMap());

      totalAmount += item.purchasePrice * item.quantity;
    }

    final Map<String, dynamic> financialTransactionData = {
      'flow': 'expense',
      'type': 'purchase',
      'supplierId': supplier.id,
      'supplierName': supplier.name,
      'items': purchaseItems
          .map((item) => {
                'productId': item.product.id,
                'productName': '${item.product.name} (${item.variant.name})',
                'quantity': item.quantity,
                'purchasePrice': item.purchasePrice,
              })
          .toList(),
      'totalAmount': totalAmount,
      'userId': user.uid,
      'userName': user.nama,
      'createdAt': DateTime.now(),
    };
    batch.set(purchaseDocRef, financialTransactionData);

    await batch.commit();
  }

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

  // --- Read Methods ---
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

  // --- Supplier Methods ---
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

  // --- Member Methods ---
  Stream<List<Member>> getMembersStream() {
    return _db.collection('members').orderBy('name').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => Member.fromFirestore(doc)).toList());
  }

  Future<void> addMember(Member member) async {
    await _db.collection('members').add(member.toMap());
  }

  Future<void> updateMember(Member member) async {
    if (member.id == null) return;
    await _db.collection('members').doc(member.id).update(member.toMap());
  }

  Future<void> deleteMember(String memberId) async {
    await _db.collection('members').doc(memberId).delete();
  }
}
