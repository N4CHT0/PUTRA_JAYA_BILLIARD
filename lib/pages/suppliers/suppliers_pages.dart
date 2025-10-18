// lib/pages/suppliers/suppliers_pages.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive Flutter
// Import model LOKAL
import 'package:putra_jaya_billiard/models/local_supplier.dart';
// Import service LOKAL
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class SuppliersPage extends StatefulWidget {
  // Hapus kodeOrganisasi jika tidak diperlukan lagi
  // final String kodeOrganisasi;

  const SuppliersPage({super.key}); // Hapus parameter

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  // Gunakan service LOKAL
  final LocalDatabaseService _localDbService = LocalDatabaseService();

  void _showSupplierDialog({LocalSupplier? supplier, dynamic supplierKey}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: supplier?.name);
    final addressController = TextEditingController(text: supplier?.address);
    final phoneController = TextEditingController(text: supplier?.phone);
    bool isActive = supplier?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
              supplier == null ? 'Tambah Supplier Baru' : 'Edit Supplier',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Nama Supplier'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: addressController,
                          decoration:
                              const InputDecoration(labelText: 'Alamat'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: phoneController,
                          decoration:
                              const InputDecoration(labelText: 'No. Telepon'),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Supplier Aktif'),
                        value: isActive,
                        onChanged: (bool? value) =>
                            setState(() => isActive = value ?? true),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.teal,
                      )
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newSupplier = LocalSupplier(
                    // id tidak diisi manual saat tambah
                    name: nameController.text,
                    address: addressController.text,
                    phone: phoneController.text,
                    isActive: isActive,
                  );

                  try {
                    if (supplier == null) {
                      // Tambah supplier baru ke Hive
                      await _localDbService.addSupplier(newSupplier);
                    } else {
                      // Update supplier yang ada di Hive menggunakan key
                      await _localDbService.updateSupplier(
                          supplierKey, newSupplier);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Gagal menyimpan: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
      LocalSupplier supplier, dynamic supplierKey) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Supplier?'),
        content: Text('Anda yakin ingin menghapus ${supplier.name}?'),
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

    if (confirm == true) {
      try {
        await _localDbService.deleteSupplier(supplierKey); // Gunakan key
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${supplier.name} berhasil dihapus.'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Manajemen Supplier'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showSupplierDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Supplier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                // Gunakan ValueListenableBuilder untuk data Hive
                child: ValueListenableBuilder<Box<LocalSupplier>>(
                  valueListenable: _localDbService.getSupplierListenable(),
                  builder: (context, box, _) {
                    final suppliers = box.values.toList().cast<LocalSupplier>();
                    // Urutkan berdasarkan nama jika perlu
                    suppliers.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    if (suppliers.isEmpty) {
                      return const Center(child: Text('Belum ada supplier.'));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.all(
                              Colors.white.withOpacity(0.1)),
                          columns: const [
                            DataColumn(label: Text('Nama')),
                            DataColumn(label: Text('Alamat')),
                            DataColumn(label: Text('Telepon')),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: suppliers.map((supplier) {
                            final supplierKey =
                                supplier.key; // Dapatkan key Hive
                            return DataRow(
                              cells: [
                                DataCell(Text(supplier.name)),
                                DataCell(Text(supplier.address)),
                                DataCell(Text(supplier.phone)),
                                DataCell(
                                  Icon(
                                    supplier.isActive
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: supplier.isActive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _showSupplierDialog(
                                            supplier: supplier,
                                            supplierKey:
                                                supplierKey), // Kirim key
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showDeleteConfirmation(supplier,
                                                supplierKey), // Kirim key
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
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
