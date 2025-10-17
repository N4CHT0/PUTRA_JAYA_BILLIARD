// lib/widgets/transaction_detail_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionDetailDialog extends StatelessWidget {
  final Map<String, dynamic> transactionData;

  const TransactionDetailDialog({super.key, required this.transactionData});

  @override
  Widget build(BuildContext context) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final type = transactionData['type'] ?? 'unknown';

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
    final startTime = (transactionData['startTime'] as Timestamp).toDate();
    final endTime = (transactionData['endTime'] as Timestamp).toDate();
    final duration =
        Duration(seconds: transactionData['durationInSeconds'] ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Billing Meja'),
        _buildDetailRow('Meja', '${transactionData['tableId']}'),
        _buildDetailRow('Kasir', transactionData['cashierName'] ?? 'N/A'),
        _buildDetailRow('Waktu Mulai',
            DateFormat('dd MMM yyyy, HH:mm:ss').format(startTime)),
        _buildDetailRow('Waktu Selesai',
            DateFormat('dd MMM yyyy, HH:mm:ss').format(endTime)),
        _buildDetailRow('Durasi',
            "${duration.inHours}j ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}d"),
        const Divider(height: 20, color: Colors.white24),
        _buildDetailRow(
            'Total', formatter.format(transactionData['totalAmount']),
            isTotal: true),
      ],
    );
  }

  Widget _buildPosDetails(NumberFormat formatter) {
    final items = (transactionData['items'] as List<dynamic>);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Penjualan POS'),
        _buildDetailRow('Kasir', transactionData['cashierName'] ?? 'N/A'),
        _buildDetailRow(
            'Waktu',
            DateFormat('dd MMM yyyy, HH:mm')
                .format((transactionData['createdAt'] as Timestamp).toDate())),
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
        _buildDetailRow(
            'Total', formatter.format(transactionData['totalAmount']),
            isTotal: true),
      ],
    );
  }

  Widget _buildPurchaseDetails(NumberFormat formatter) {
    final items = (transactionData['items'] as List<dynamic>);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Jenis', 'Pembelian Stok'),
        _buildDetailRow('Supplier', transactionData['supplierName'] ?? 'N/A'),
        // <-- POIN PENTING 3: Nama pengguna ditampilkan di sini
        _buildDetailRow('Dicatat oleh', transactionData['userName'] ?? 'N/A'),
        _buildDetailRow(
            'Waktu',
            DateFormat('dd MMM yyyy, HH:mm')
                .format((transactionData['createdAt'] as Timestamp).toDate())),
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
        _buildDetailRow(
            'Total', formatter.format(transactionData['totalAmount']),
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
