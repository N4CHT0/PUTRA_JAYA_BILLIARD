import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/local_transaction.dart'; // Import model LocalTransaction

class TransactionDetailDialog extends StatelessWidget {
  // Terima objek LocalTransaction, bukan Map
  final LocalTransaction transaction;

  const TransactionDetailDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    // Ambil tipe langsung dari properti objek
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

  Widget _buildBilliardDetails(NumberFormat formatter) {
    // Ambil data langsung dari objek 'transaction', dan tangani nilai null
    final startTime = transaction.startTime;
    final endTime = transaction.endTime;
    final duration = Duration(seconds: transaction.durationInSeconds ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Billing Meja'),
        // Tampilkan memberName jika ada dan tidak null/kosong
        if (transaction.memberName != null &&
            transaction.memberName!.isNotEmpty)
          _buildDetailRow('Pelanggan', transaction.memberName!),
        _buildDetailRow('Meja', '${transaction.tableId ?? 'N/A'}'),
        _buildDetailRow('Kasir', transaction.cashierName),
        // Format DateTime, beri nilai default jika null
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
        const Divider(height: 20, color: Colors.white24),
        _buildDetailRow('Total', formatter.format(transaction.totalAmount),
            isTotal: true),
      ],
    );
  }

  Widget _buildPosDetails(NumberFormat formatter) {
    // Ambil data langsung dan tangani null
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
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
                '- ${item['quantity']}x ${item['productName']} @ ${formatter.format(item['price'])}'),
          );
        }).toList(),
        const Divider(height: 20, color: Colors.white24),
        _buildDetailRow('Total', formatter.format(transaction.totalAmount),
            isTotal: true),
      ],
    );
  }

  Widget _buildPurchaseDetails(NumberFormat formatter) {
    final items = transaction.items ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Pembelian Stok'),
        _buildDetailRow('Supplier', transaction.supplierName ?? 'N/A'),
        _buildDetailRow('Dicatat oleh',
            transaction.cashierName), // asumsi kasir yg mencatat
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
        }).toList(),
        const Divider(height: 20, color: Colors.white24),
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
