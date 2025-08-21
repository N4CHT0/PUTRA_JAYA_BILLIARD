import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;

// --- TAMBAHKAN IMPORT INI UNTUK MENGENALI Tipe Timestamp ---
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfGenerator {
  static Future<void> printReport(
    String title,
    List<Map<String, dynamic>> transactions,
    double totalRevenue,
  ) async {
    final doc = pw.Document();

    // Fungsi format
    String formatCurrency(double amount) => intl.NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);

    // Sekarang fungsi ini akan mengenali 'Timestamp'
    String formatTimestamp(Timestamp ts) =>
        intl.DateFormat('dd/MM/yy HH:mm').format(ts.toDate());

    String formatDuration(int seconds) {
      final d = Duration(seconds: seconds);
      return "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}";
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            'Tanggal Cetak: ${intl.DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'Meja',
              'Waktu Mulai',
              'Durasi (Jam:Menit)',
              'Total Biaya',
            ],
            data: transactions
                .map(
                  (trx) => [
                    trx['tableId'].toString(),
                    formatTimestamp(trx['startTime']),
                    formatDuration(trx['durationInSeconds']),
                    formatCurrency(trx['totalCost']),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Pendapatan: ${formatCurrency(totalRevenue)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}
