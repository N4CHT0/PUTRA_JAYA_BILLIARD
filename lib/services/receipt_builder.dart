// lib/services/receipt_builder.dart

// ignore_for_file: unused_field

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';

// Tipe nota untuk membedakan footer/header
enum ReceiptType { customer, cashier, kitchen }

class ReceiptBuilder {
  final List<int> _bytes = [];
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy HH:mm:ss');
  // Lebar kertas printer dalam karakter (umumnya 32 untuk 58mm)
  static const int _paperWidth = 32;

  // Perintah dasar ESC/POS
  static const List<int> _escInit = [0x1B, 0x40];
  static const List<int> _alignCenter = [0x1B, 0x61, 1];
  static const List<int> _alignLeft = [0x1B, 0x61, 0];
  static const List<int> _boldOn = [0x1B, 0x45, 1];
  static const List<int> _boldOff = [0x1B, 0x45, 0];
  static const List<int> _cutPaper = [0x1D, 0x56, 66, 0];

  // Fungsi untuk menambahkan teks ke buffer
  void _addText(String text, {List<int>? styles}) {
    if (styles != null) {
      _bytes.addAll(styles);
    }
    _bytes.addAll(text.codeUnits);
  }

  // Garis pemisah
  void _addDivider() {
    _addText('${'-' * _paperWidth}\n', styles: _alignLeft);
  }

  // Fungsi utama untuk membuat nota dari transaksi F&B (POS)
  static Uint8List buildPosReceipt(
      LocalTransaction transaction, ReceiptType type) {
    final builder = ReceiptBuilder();
    builder._buildHeader(type);
    builder._buildTransactionInfo(transaction);
    if (transaction.items != null && transaction.items!.isNotEmpty) {
      builder._buildItems(transaction.items!);
    }
    builder._buildFooter(transaction, type);
    return Uint8List.fromList(builder._bytes);
  }

  // REFACTORED: Fungsi utama untuk membuat nota dari billing billiard (Dashboard)
  // Sekarang hanya butuh LocalTransaction karena sudah berisi semua data F&B
  static Uint8List buildBilliardReceipt(
      LocalTransaction transaction, ReceiptType type) {
    final builder = ReceiptBuilder();
    builder._buildHeader(type);
    builder._buildTransactionInfo(transaction);
    builder._buildBilliardDetails(transaction);

    // Cek jika ada pesanan F&B dari transaksi yang sama
    if (transaction.items != null && transaction.items!.isNotEmpty) {
      builder._addText('--- Pesanan F&B ---\n', styles: _alignCenter);
      builder._buildItems(transaction.items!);
    }
    builder._buildFooter(transaction, type);
    return Uint8List.fromList(builder._bytes);
  }

  // Fungsi untuk membuat pesanan dapur (tidak berubah, karena datanya dari keranjang)
  static Uint8List buildKitchenOrder(List<CartItem> items, int tableId) {
    final builder = ReceiptBuilder();
    builder._bytes.addAll(_escInit);
    builder._addText('** PESANAN DAPUR **\n',
        styles: [..._alignCenter, ..._boldOn]);
    builder._addText('================================\n',
        styles: _alignCenter);
    builder._addText('Meja: $tableId\n', styles: [..._alignLeft, ..._boldOn]);
    builder
        ._addText('Waktu: ${builder._dateFormat.format(DateTime.now())}\n\n');

    for (var item in items) {
      String itemName = item.product.name;
      if (item.selectedVariant != null) {
        itemName += ' (${item.selectedVariant!.name})';
      }
      builder._addText('${item.quantity}x $itemName\n', styles: _boldOn);
      if (item.note != null && item.note!.isNotEmpty) {
        builder._addText('   Catatan: ${item.note}\n');
      }
    }

    builder._addText('\n\n\n');
    builder._bytes.addAll(_cutPaper);
    return Uint8List.fromList(builder._bytes);
  }

  void _buildHeader(ReceiptType type) {
    _bytes.addAll(_escInit);
    _addText('Putra Jaya Billiard\n', styles: [..._alignCenter, ..._boldOn]);
    _addText('Jl. Contoh Alamat No. 123\n', styles: _alignCenter);
    _addDivider();

    String typeText = '';
    switch (type) {
      case ReceiptType.customer:
        typeText = 'SALINAN PELANGGAN';
        break;
      case ReceiptType.cashier:
        typeText = 'SALINAN KASIR';
        break;
      case ReceiptType.kitchen:
        typeText = 'SALINAN DAPUR';
        break;
    }
    if (typeText.isNotEmpty) {
      _addText('$typeText\n', styles: _alignCenter);
    }
  }

  void _buildTransactionInfo(LocalTransaction transaction) {
    _addText('No: ${transaction.key}\n', styles: _alignLeft);
    _addText('Kasir: ${transaction.cashierName}\n');
    _addText('Waktu: ${_dateFormat.format(transaction.createdAt)}\n');
    if (transaction.memberName != null) {
      _addText('Member: ${transaction.memberName}\n');
    }
    _addDivider();
  }

  void _buildBilliardDetails(LocalTransaction transaction) {
    if (transaction.tableId != null) {
      _addText('Meja Billiard: ${transaction.tableId}\n');
    }
    if (transaction.durationInSeconds != null) {
      final duration = Duration(seconds: transaction.durationInSeconds!);
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final hours = twoDigits(duration.inHours);
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      _addText('Durasi Main: $hours:$minutes:$seconds\n');
    }
    _addDivider();
  }

  // REFACTORED: Format item menjadi 2 baris agar lebih rapi
  void _buildItems(List<Map<dynamic, dynamic>> items) {
    for (var item in items) {
      String name = item['productName'];
      if (item['variantName'] != null) {
        name += ' (${item['variantName']})';
      }
      final qty = item['quantity'];
      final price = item['price'];
      final lineTotal = qty * price;

      // Baris 1: Kuantitas dan Nama Item
      _addText('$qty x $name\n');

      // Baris 2: Total harga untuk item ini, rata kanan
      String totalString = _currencyFormat.format(lineTotal);
      _addText('${totalString.padLeft(_paperWidth)}\n');

      // Baris 3 (opsional): Catatan
      if (item['note'] != null && item['note'].isNotEmpty) {
        _addText('  Catatan: ${item['note']}\n');
      }
    }
    _addDivider();
  }

  void _buildFooter(LocalTransaction transaction, ReceiptType type) {
    // Helper untuk membuat baris harga (contoh: 'Subtotal:      10.000')
    String priceRow(String label, double amount) {
      String formattedAmount = _currencyFormat.format(amount);
      return '${label.padRight(_paperWidth - formattedAmount.length)}$formattedAmount\n';
    }

    _addText(priceRow('Subtotal', transaction.subtotal ?? 0));

    if (transaction.discount != null && transaction.discount! > 0) {
      _addText(priceRow('Diskon', -transaction.discount!));
    }

    _addText(priceRow('Total', transaction.totalAmount), styles: _boldOn);
    _addText('Metode Bayar: ${transaction.paymentMethod}\n');

    _addText('\n');
    if (type == ReceiptType.customer) {
      _addText('Terima kasih atas kunjungan Anda!\n', styles: _alignCenter);
    } else {
      _addText('Simpan nota ini sebagai bukti.\n', styles: _alignCenter);
    }
    _addText('\n\n\n');
    _bytes.addAll(_cutPaper);
  }
}
