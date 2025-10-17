import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = intl.NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      // --- PERUBAHAN: Latar belakang gradasi ---
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Riwayat Transaksi'),
          // --- PERUBAHAN: AppBar transparan ---
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .orderBy(
                'startTime',
                descending: true,
              ) // Lebih baik urutkan berdasarkan waktu mulai
              .snapshots(),
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

            // --- PERUBAHAN: Menggunakan ListView dengan kartu modern ---
            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final doc = transactions[index];
                final data = doc.data() as Map<String, dynamic>;
                final startTime = (data['startTime'] as Timestamp).toDate();
                final totalCost = data['totalCost'] as double;
                final duration = Duration(
                  seconds: data['durationInSeconds'] ?? 0,
                );
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    title: Text(
                      'Meja ${data['tableId']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${intl.DateFormat('dd MMM yyyy, HH:mm').format(startTime)} • Durasi: $durationString',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatter.format(totalCost),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            final confirm = await _showDeleteConfirmationDialog(
                              context,
                            );
                            if (confirm == true) {
                              await FirebaseFirestore.instance
                                  .collection('transactions')
                                  .doc(doc.id)
                                  .delete();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET BARU: Dialog konfirmasi dengan tema gelap ---
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
