import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/services/firebase_service.dart';
import 'package:putra_jaya_billiard/widgets/transactions_detail_dialog.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    final formatter = intl.NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Riwayat Arus Kas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getFinancialTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Belum ada transaksi.',
                style: TextStyle(color: Colors.grey[400]),
              ),
            );
          }

          final transactions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final doc = transactions[index];
              final data = doc.data() as Map<String, dynamic>;
              // -- DIBUNGKUS DENGAN INKWELL AGAR BISA DI-KLIK --
              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        TransactionDetailDialog(transactionData: data),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: _buildTransactionCard(
                    context, doc, data, formatter, firebaseService),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(
      BuildContext context,
      DocumentSnapshot doc,
      Map<String, dynamic> data,
      intl.NumberFormat formatter,
      FirebaseService firebaseService) {
    final isIncome = data['flow'] == 'income';
    final type = data['type'] ?? 'unknown';
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final totalAmount = data['totalAmount'] as double;

    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case 'billiard':
        title = 'Billing Meja ${data['tableId']}';
        final duration = Duration(seconds: data['durationInSeconds'] ?? 0);
        subtitle = "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";
        icon = Icons.pool;
        break;
      case 'pos':
        title = 'Penjualan POS';
        final items = data['items'] as List<dynamic>?;
        final totalItems = items?.fold<int>(
                0,
                (sum, item) =>
                    sum + ((item['quantity'] ?? 0) as num).toInt()) ??
            0;
        subtitle = '$totalItems item oleh ${data['cashierName']}';
        icon = Icons.point_of_sale;
        break;
      case 'purchase':
        title = 'Pembelian Stok';
        subtitle = 'dari ${data['supplierName']}';
        icon = Icons.shopping_cart;
        break;
      default:
        title = 'Transaksi Lain';
        subtitle = 'Tidak diketahui';
        icon = Icons.receipt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: isIncome ? Colors.greenAccent : Colors.redAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            Text(intl.DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? '+' : '-'} ${formatter.format(totalAmount)}',
              style: TextStyle(
                fontSize: 16,
                color: isIncome ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey),
              onPressed: () async {
                final confirm = await _showDeleteConfirmationDialog(context);
                if (confirm == true) {
                  await firebaseService.deleteFinancialTransaction(doc.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Transaksi?'),
        content: const Text('Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
