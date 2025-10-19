// lib/services/local_database_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Dibiarkan ada sesuai kode asli Anda
import '../models/local_product.dart';
import '../models/local_member.dart';
import '../models/local_supplier.dart';
import '../models/local_transaction.dart';
import '../models/local_stock_mutation.dart';
import '../models/local_payment_method.dart';
// Import ProductVariant tidak diperlukan di sini karena tidak digunakan secara langsung

class LocalDatabaseService {
  static const _productsBox = 'products';
  static const _membersBox = 'members';
  static const _suppliersBox = 'suppliers';
  static const _transactionsBox = 'transactions';
  static const _stockMutationsBox = 'stock_mutations';
  static const _paymentMethodsBox = 'payment_methods';

  static final List<String> _allBoxNames = [
    _productsBox,
    _membersBox,
    _suppliersBox,
    _transactionsBox,
    _stockMutationsBox,
    _paymentMethodsBox,
  ];

  static Future<void> init() async {
    await Hive.openBox<LocalProduct>(_productsBox);
    await Hive.openBox<LocalMember>(_membersBox);
    await Hive.openBox<LocalSupplier>(_suppliersBox);
    await Hive.openBox<LocalTransaction>(_transactionsBox);
    await Hive.openBox<LocalStockMutation>(_stockMutationsBox);
    await Hive.openBox<LocalPaymentMethod>(_paymentMethodsBox);
  }

  // --- SEMUA FUNGSI DI BAWAH INI TETAP SAMA SEPERTI KODE ASLI ANDA ---

  Future<String> backupData() async {
    final Map<String, dynamic> allData = {};
    for (var boxName in _allBoxNames) {
      Box box;
      switch (boxName) {
        case _productsBox:
          box = Hive.box<LocalProduct>(_productsBox);
          break;
        case _membersBox:
          box = Hive.box<LocalMember>(_membersBox);
          break;
        case _suppliersBox:
          box = Hive.box<LocalSupplier>(_suppliersBox);
          break;
        case _transactionsBox:
          box = Hive.box<LocalTransaction>(_transactionsBox);
          break;
        case _stockMutationsBox:
          box = Hive.box<LocalStockMutation>(_stockMutationsBox);
          break;
        case _paymentMethodsBox:
          box = Hive.box<LocalPaymentMethod>(_paymentMethodsBox);
          break;
        default:
          continue;
      }
      final Map<String, dynamic> boxData = {};
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          // Menggunakan dynamic dispatch untuk memastikan toJson ada
          boxData[key.toString()] = (item as dynamic).toJson();
        }
      }
      allData[boxName] = boxData;
    }
    final jsonString = jsonEncode(allData);
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih Folder untuk Menyimpan Backup',
    );
    if (selectedDirectory == null) {
      return 'Backup dibatalkan: Tidak ada folder dipilih.';
    }
    final path = selectedDirectory;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'putra_jaya_billiard_backup_$timestamp.json';
    final file = File('$path/$fileName');
    await file.writeAsString(jsonString);
    return 'Backup berhasil disimpan di: ${file.path}';
  }

  Future<File?> _pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  Future<String> restoreData() async {
    final file = await _pickJsonFile();
    if (file == null) return "Restore dibatalkan: Tidak ada file dipilih.";
    final jsonString = await file.readAsString();
    final Map<String, dynamic> allData = jsonDecode(jsonString);
    await resetAllData();
    await _importDataFromFile(allData);
    return 'Restore data dari ${file.path.split('/').last} berhasil.';
  }

  Future<String> importData() async {
    final file = await _pickJsonFile();
    if (file == null) return "Import dibatalkan: Tidak ada file dipilih.";
    final jsonString = await file.readAsString();
    final Map<String, dynamic> allData = jsonDecode(jsonString);
    await _importDataFromFile(allData);
    return 'Import data dari ${file.path.split('/').last} berhasil.';
  }

  Future<void> _importDataFromFile(Map<String, dynamic> allData) async {
    for (var boxName in allData.keys) {
      if (!_allBoxNames.contains(boxName)) continue;
      final Map<String, dynamic> items = allData[boxName];
      for (var entry in items.entries) {
        final dynamic key = int.tryParse(entry.key) ?? entry.key;
        final itemMap = entry.value as Map<String, dynamic>;
        switch (boxName) {
          case _productsBox:
            await Hive.box<LocalProduct>(_productsBox)
                .put(key, LocalProduct.fromJson(itemMap));
            break;
          case _membersBox:
            await Hive.box<LocalMember>(_membersBox)
                .put(key, LocalMember.fromJson(itemMap));
            break;
          case _suppliersBox:
            await Hive.box<LocalSupplier>(_suppliersBox)
                .put(key, LocalSupplier.fromJson(itemMap));
            break;
          case _transactionsBox:
            await Hive.box<LocalTransaction>(_transactionsBox)
                .put(key, LocalTransaction.fromJson(itemMap));
            break;
          case _stockMutationsBox:
            await Hive.box<LocalStockMutation>(_stockMutationsBox)
                .put(key, LocalStockMutation.fromJson(itemMap));
            break;
          case _paymentMethodsBox:
            await Hive.box<LocalPaymentMethod>(_paymentMethodsBox)
                .put(key, LocalPaymentMethod.fromJson(itemMap));
            break;
        }
      }
    }
  }

  Future<void> resetAllData() async {
    for (var boxName in _allBoxNames) {
      await Hive.box(boxName).clear();
    }
  }

  // --- Payment Method Methods (TETAP SAMA) ---
  ValueListenable<Box<LocalPaymentMethod>> getPaymentMethodsListenable() =>
      Hive.box<LocalPaymentMethod>(_paymentMethodsBox).listenable();
  Future<void> addPaymentMethod(LocalPaymentMethod method) async =>
      await Hive.box<LocalPaymentMethod>(_paymentMethodsBox).add(method);
  Future<void> updatePaymentMethod(
          dynamic key, LocalPaymentMethod method) async =>
      await Hive.box<LocalPaymentMethod>(_paymentMethodsBox).put(key, method);
  Future<void> deletePaymentMethod(dynamic key) async =>
      await Hive.box<LocalPaymentMethod>(_paymentMethodsBox).delete(key);

  // --- Product Methods (BAGIAN YANG DIPERBAIKI & DILENGKAPI) ---
  ValueListenable<Box<LocalProduct>> getProductListenable() =>
      Hive.box<LocalProduct>(_productsBox).listenable();
  Future<void> addProduct(LocalProduct product) async =>
      await Hive.box<LocalProduct>(_productsBox).add(product);

  // ✅ METHOD UPDATE YANG HILANG, SEKARANG DITAMBAHKAN
  Future<void> updateProduct(dynamic key, LocalProduct product) async =>
      await Hive.box<LocalProduct>(_productsBox).put(key, product);

  // ✅ METHOD DELETE YANG HILANG, SEKARANG DITAMBAHKAN
  Future<void> deleteProduct(dynamic key) async =>
      await Hive.box<LocalProduct>(_productsBox).delete(key);

  LocalProduct? getProductByKey(dynamic key) =>
      Hive.box<LocalProduct>(_productsBox).get(key);

  // ✅ FUNGSI UPDATE STOK DISEMPURNAKAN MENGGUNAKAN .put()
  Future<void> increaseStockForPurchase(
      dynamic productKey, int quantity, double newPurchasePrice) async {
    final box = Hive.box<LocalProduct>(_productsBox);
    final product = box.get(productKey);
    if (product != null) {
      product.stock += quantity;
      product.purchasePrice = newPurchasePrice;
      await box.put(productKey, product); // Mengganti .save() dengan .put()
    } else {
      throw Exception('Produk tidak ditemukan');
    }
  }

  // ✅ FUNGSI UPDATE STOK DISEMPURNAKAN MENGGUNAKAN .put()
  Future<void> decreaseStockForSale(
      dynamic productKey, int quantitySold) async {
    final box = Hive.box<LocalProduct>(_productsBox);
    final product = box.get(productKey);
    if (product != null) {
      product.stock -= quantitySold;
      await box.put(productKey, product); // Mengganti .save() dengan .put()
    } else {
      throw Exception('Produk tidak ditemukan');
    }
  }

  // --- Member Methods (TETAP SAMA) ---
  ValueListenable<Box<LocalMember>> getMemberListenable() =>
      Hive.box<LocalMember>(_membersBox).listenable();
  Future<void> addMember(LocalMember member) async =>
      await Hive.box<LocalMember>(_membersBox).add(member);
  Future<void> updateMember(dynamic key, LocalMember member) async =>
      await Hive.box<LocalMember>(_membersBox).put(key, member);
  Future<void> deleteMember(dynamic key) async =>
      await Hive.box<LocalMember>(_membersBox).delete(key);

  // --- Supplier Methods (TETAP SAMA) ---
  ValueListenable<Box<LocalSupplier>> getSupplierListenable() =>
      Hive.box<LocalSupplier>(_suppliersBox).listenable();
  Future<void> addSupplier(LocalSupplier supplier) async =>
      await Hive.box<LocalSupplier>(_suppliersBox).add(supplier);
  Future<void> updateSupplier(dynamic key, LocalSupplier supplier) async =>
      await Hive.box<LocalSupplier>(_suppliersBox).put(key, supplier);
  Future<void> deleteSupplier(dynamic key) async =>
      await Hive.box<LocalSupplier>(_suppliersBox).delete(key);

  // --- Transaction Methods (TETAP SAMA) ---
  ValueListenable<Box<LocalTransaction>> getTransactionListenable() =>
      Hive.box<LocalTransaction>(_transactionsBox).listenable();
  Future<void> addTransaction(LocalTransaction transaction) async =>
      await Hive.box<LocalTransaction>(_transactionsBox).add(transaction);
  Future<void> deleteTransaction(dynamic key) async =>
      await Hive.box<LocalTransaction>(_transactionsBox).delete(key);

  List<LocalTransaction> getTransactionsBetween(DateTime start, DateTime end) {
    var transactions = Hive.box<LocalTransaction>(_transactionsBox)
        .values
        .where((trx) =>
            !trx.createdAt.isBefore(start) && trx.createdAt.isBefore(end))
        .toList();
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  // --- Stock Mutation Methods (TETAP SAMA) ---
  Future<void> addStockMutation(LocalStockMutation mutation) async =>
      await Hive.box<LocalStockMutation>(_stockMutationsBox).add(mutation);

  List<LocalStockMutation> getMutationsForProduct(String productId) {
    var mutations = Hive.box<LocalStockMutation>(_stockMutationsBox)
        .values
        .where((m) => m.productId == productId)
        .toList();
    mutations.sort((a, b) => b.date.compareTo(a.date));
    return mutations;
  }
}
