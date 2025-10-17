import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/services/firebase_service.dart';

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
        title: const Text('Riwayat Transaksi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getTransactionsStream(),
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

              if (data['type'] == 'billiard') {
                return _buildBilliardCard(
                    context, doc, data, formatter, firebaseService);
              } else if (data['type'] == 'pos') {
                return _buildPosCard(
                    context, doc, data, formatter, firebaseService);
              } else {
                return const SizedBox.shrink();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBilliardCard(
      BuildContext context,
      DocumentSnapshot doc,
      Map<String, dynamic> data,
      intl.NumberFormat formatter,
      FirebaseService firebaseService) {
    final startTime = (data['createdAt'] as Timestamp).toDate();
    final totalCost = data['totalAmount'] as double;
    final duration = Duration(seconds: data['durationInSeconds'] ?? 0);
    final durationString =
        "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: const Icon(Icons.pool, color: Colors.cyanAccent),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          'Meja ${data['tableId']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${intl.DateFormat('dd MMM yyyy, HH:mm').format(startTime)} • Durasi: $durationString',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        trailing: _buildTrailing(
            context, doc.id, totalCost, formatter, firebaseService),
      ),
    );
  }

  Widget _buildPosCard(
      BuildContext context,
      DocumentSnapshot doc,
      Map<String, dynamic> data,
      intl.NumberFormat formatter,
      FirebaseService firebaseService) {
    final transactionTime = (data['createdAt'] as Timestamp).toDate();
    final totalAmount = data['totalAmount'] as double;
    final cashierName = data['cashierName'] ?? 'N/A';

    final items = data['items'] as List<dynamic>?;
    // --- PERBAIKAN ERROR 'num' is not a subtype of 'int' ---
    final totalItems = items?.fold<int>(
            0, (sum, item) => sum + ((item['quantity'] ?? 0) as num).toInt()) ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: const Icon(Icons.point_of_sale, color: Colors.amberAccent),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: const Text(
          'Transaksi POS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${intl.DateFormat('dd MMM yyyy, HH:mm').format(transactionTime)} • $totalItems item oleh $cashierName',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        trailing: _buildTrailing(
            context, doc.id, totalAmount, formatter, firebaseService),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, String docId, double amount,
      intl.NumberFormat formatter, FirebaseService firebaseService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatter.format(amount),
          style: const TextStyle(fontSize: 16, color: Colors.cyanAccent),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () async {
            final confirm = await _showDeleteConfirmationDialog(context);
            if (confirm == true) {
              await firebaseService.deleteTransaction(docId);
            }
          },
        ),
      ],
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
