import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/local_transaction.dart';

class TransactionDetailDialog extends StatelessWidget {
  final LocalTransaction transaction;

  const TransactionDetailDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final type = transaction.type;

    return AlertDialog(
      backgroundColor: const Color(0xFF2c2c2c),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Detail Transaksi'),
      content: SingleChildScrollView(
        child: _buildContent(type, formatter),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildContent(String type, NumberFormat formatter) {
    switch (type) {
      case 'billiard':
        return _buildBilliardDetails(formatter);
      case 'pos':
        return _buildPosDetails(formatter);
      case 'purchase':
        return _buildPurchaseDetails(formatter);
      default:
        return const Text('Tipe transaksi tidak dikenal.');
    }
  }

  // --- BAGIAN YANG DIPERBARUI UNTUK MENAMPILKAN VARIAN & CATATAN ---
  Widget _buildItemDetails(Map<String, dynamic> item, NumberFormat formatter) {
    // 1. Bangun nama produk lengkap dengan varian
    String productName = item['productName'] ?? 'Nama Produk Tidak Ada';
    final String? variantName = item['variantName'];
    if (variantName != null && variantName.isNotEmpty) {
      productName += ' ($variantName)';
    }

    // 2. Siapkan widget untuk catatan (jika ada)
    final String? note = item['note'];
    Widget? noteWidget;
    if (note != null && note.isNotEmpty) {
      noteWidget = Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 2.0),
        child: Text(
          'Catatan: $note',
          style: const TextStyle(
              fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    // 3. Gabungkan semuanya dalam satu Column
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '- ${item['quantity']}x $productName @ ${formatter.format(item['price'])}'),
          if (noteWidget != null) noteWidget,
        ],
      ),
    );
  }

  Widget _buildBilliardDetails(NumberFormat formatter) {
    final startTime = transaction.startTime;
    final endTime = transaction.endTime;
    final duration = Duration(seconds: transaction.durationInSeconds ?? 0);
    final items = transaction.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Billing Meja'),
        if (transaction.memberName != null &&
            transaction.memberName!.isNotEmpty)
          _buildDetailRow('Pelanggan', transaction.memberName!),
        _buildDetailRow('Meja', '${transaction.tableId ?? 'N/A'}'),
        _buildDetailRow('Kasir', transaction.cashierName),
        _buildDetailRow(
            'Waktu Mulai',
            startTime != null
                ? DateFormat('dd MMM yyyy, HH:mm:ss').format(startTime)
                : 'N/A'),
        _buildDetailRow(
            'Waktu Selesai',
            endTime != null
                ? DateFormat('dd MMM yyyy, HH:mm:ss').format(endTime)
                : 'N/A'),
        _buildDetailRow('Durasi',
            "${duration.inHours}j ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}d"),
        _buildDetailRow('Metode Bayar', transaction.paymentMethod ?? 'Cash'),
        if (items.isNotEmpty) ...[
          const Divider(height: 20, color: Colors.white24),
          const Text('Pesanan Tambahan (F&B):',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Menggunakan helper widget yang baru
          ...items.map((item) => _buildItemDetails(item, formatter)),
        ],
        const Divider(height: 20, color: Colors.white24),
        _buildDetailRow('Total', formatter.format(transaction.totalAmount),
            isTotal: true),
      ],
    );
  }

  Widget _buildPosDetails(NumberFormat formatter) {
    final items = transaction.items ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Penjualan POS'),
        if (transaction.memberName != null &&
            transaction.memberName!.isNotEmpty)
          _buildDetailRow('Pelanggan', transaction.memberName!),
        _buildDetailRow('Kasir', transaction.cashierName),
        _buildDetailRow('Waktu',
            DateFormat('dd MMM yyyy, HH:mm').format(transaction.createdAt)),
        const Divider(height: 20, color: Colors.white24),
        const Text('Daftar Item:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Menggunakan helper widget yang baru
        ...items.map((item) => _buildItemDetails(item, formatter)),

        const Divider(height: 20, color: Colors.white24),
        _buildDetailRow(
            'Subtotal', formatter.format(transaction.subtotal ?? 0)),
        if (transaction.discount != null && transaction.discount! > 0)
          _buildDetailRow(
              'Diskon', '- ${formatter.format(transaction.discount)}'),
        _buildDetailRow('Metode Bayar', transaction.paymentMethod ?? 'Cash'),
        _buildDetailRow('Total', formatter.format(transaction.totalAmount),
            isTotal: true),
      ],
    );
  }

  // Method ini tidak diubah karena pembelian tidak memiliki varian/catatan
  Widget _buildPurchaseDetails(NumberFormat formatter) {
    final items = transaction.items ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Pembelian Stok'),
        _buildDetailRow('Supplier', transaction.supplierName ?? 'N/A'),
        _buildDetailRow('Dicatat oleh', transaction.cashierName),
        _buildDetailRow('Waktu',
            DateFormat('dd MMM yyyy, HH:mm').format(transaction.createdAt)),
        const Divider(height: 20, color: Colors.white24),
        const Text('Daftar Item:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
                '- ${item['quantity']}x ${item['productName']} @ ${formatter.format(item['purchasePrice'])}'),
          );
        }),
        const Divider(height: 20, color: Colors.white24),
        _buildDetailRow('Metode Bayar', transaction.paymentMethod ?? 'Cash'),
        _buildDetailRow('Total', formatter.format(transaction.totalAmount),
            isTotal: true),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTotal ? 18 : 14,
                color: isTotal ? Colors.cyanAccent : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
