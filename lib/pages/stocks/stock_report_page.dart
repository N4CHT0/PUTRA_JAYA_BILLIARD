// lib/pages/stocks/stock_report_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

// Helper class yang sama seperti di stock opname
class VariantStockItem {
  final LocalProduct product;
  final ProductVariant variant;

  VariantStockItem({required this.product, required this.variant});
}

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  String _searchQuery = '';
  final _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Laporan Stok Produk'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: 'Cari Nama Produk atau Varian',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                child: ValueListenableBuilder<Box<LocalProduct>>(
                  valueListenable: _localDbService.getProductListenable(),
                  builder: (context, box, _) {
                    // Ubah data menjadi daftar varian
                    List<VariantStockItem> allItems = [];
                    for (var product in box.values) {
                      for (var variant in product.variants) {
                        allItems.add(VariantStockItem(
                            product: product, variant: variant));
                      }
                    }

                    final filteredItems = allItems.where((item) {
                      final productName = item.product.name.toLowerCase();
                      final variantName = item.variant.name.toLowerCase();
                      return productName.contains(_searchQuery) ||
                          variantName.contains(_searchQuery);
                    }).toList();

                    filteredItems.sort((a, b) =>
                        '${a.product.name} ${a.variant.name}'
                            .compareTo('${b.product.name} ${b.variant.name}'));

                    if (filteredItems.isEmpty) {
                      return const Center(child: Text('Tidak ada produk.'));
                    }

                    double totalAssetValue = filteredItems.fold(
                        0.0,
                        (sum, item) =>
                            sum +
                            (item.variant.stock * item.variant.purchasePrice));

                    return Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    columnSpacing: 20,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.white.withOpacity(0.1)),
                                    columns: const [
                                      DataColumn(
                                          label: Text('Nama Produk (Varian)')),
                                      DataColumn(label: Text('Satuan')),
                                      DataColumn(
                                          label: Text('Sisa Stok'),
                                          numeric: true),
                                      DataColumn(
                                          label: Text('Harga Beli'),
                                          numeric: true),
                                      DataColumn(
                                          label: Text('Nilai Aset'),
                                          numeric: true),
                                    ],
                                    rows: filteredItems.map((item) {
                                      final variant = item.variant;
                                      final product = item.product;
                                      final assetValue =
                                          variant.stock * variant.purchasePrice;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(
                                              '${product.name} (${variant.name})')),
                                          DataCell(Text(product.unit)),
                                          DataCell(
                                            Text(
                                              variant.stock.toString(),
                                              style: TextStyle(
                                                color: variant.stock <= 5
                                                    ? Colors.redAccent
                                                    : Colors.white,
                                                fontWeight: variant.stock <= 5
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                          DataCell(Text(
                                            _currencyFormatter
                                                .format(variant.purchasePrice),
                                            textAlign: TextAlign.end,
                                          )),
                                          DataCell(Text(
                                            _currencyFormatter
                                                .format(assetValue),
                                            textAlign: TextAlign.end,
                                          )),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Nilai Aset',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontSize: 18),
                              ),
                              Text(
                                _currencyFormatter.format(totalAssetValue),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: Colors.cyanAccent, fontSize: 18),
                              ),
                            ],
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
