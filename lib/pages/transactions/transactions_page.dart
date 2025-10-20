// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/services/local_database_service.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';
import 'package:putra_jaya_billiard/widgets/transactions_detail_dialog.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final formatter = intl.NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Riwayat Arus Kas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder<Box<LocalTransaction>>(
        valueListenable: _localDbService.getTransactionListenable(),
        builder: (context, box, _) {
          final transactions = box.values.toList().cast<LocalTransaction>();
          transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (transactions.isEmpty) {
            return Center(
              child: Text(
                'Belum ada transaksi.',
                style: TextStyle(color: Colors.grey[400]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final trx = transactions[index];
              final trxKey = trx.key;

              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => TransactionDetailDialog(transaction: trx),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: _buildTransactionCard(context, trx, trxKey, formatter),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    LocalTransaction trx,
    dynamic trxKey, // Key Hive bisa int atau String
    intl.NumberFormat formatter,
  ) {
    final isIncome = trx.flow == 'income';
    final type = trx.type;
    final createdAt = trx.createdAt;
    final totalAmount = trx.totalAmount;

    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case 'billiard':
        title = 'Billing Meja ${trx.tableId}';
        final duration = Duration(seconds: trx.durationInSeconds ?? 0);
        subtitle = "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";
        icon = Icons.pool;
        break;
      case 'pos':
        title = 'Penjualan POS';
        final items = trx.items;
        final totalItems = items?.fold<int>(
                0,
                (sum, item) =>
                    sum + ((item['quantity'] ?? 0) as num).toInt()) ??
            0;
        subtitle = '$totalItems item oleh ${trx.cashierName}';
        icon = Icons.point_of_sale;
        break;
      case 'purchase':
        title = 'Pembelian Stok';
        subtitle = 'dari ${trx.supplierName}';
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
              tooltip: 'Hapus Transaksi',
              onPressed: () async {
                final confirm = await _showDeleteConfirmationDialog(
                    context, trx.type, totalAmount);
                if (confirm == true) {
                  try {
                    await _localDbService.deleteTransaction(trxKey);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Transaksi berhasil dihapus (Lokal).'),
                      backgroundColor: Colors.green,
                    ));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Gagal menghapus: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String type, double amount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Transaksi?'),
        content: Text(
            'Anda yakin ingin menghapus transaksi $type senilai ${formatter.format(amount)}? Aksi ini tidak dapat dibatalkan.'),
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
