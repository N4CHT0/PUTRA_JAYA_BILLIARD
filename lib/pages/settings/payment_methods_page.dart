// lib/pages/settings/payment_methods_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:putra_jaya_billiard/models/local_payment_method.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final LocalDatabaseService _dbService = LocalDatabaseService();

  void _showAddEditDialog({LocalPaymentMethod? method}) {
    final nameController = TextEditingController(text: method?.name ?? '');
    final formKey = GlobalKey<FormState>();
    bool isActive = method?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          title: Text(method == null ? 'Tambah Metode' : 'Edit Metode'),
          content: StatefulBuilder(
            builder: (context, setStateInDialog) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration:
                          const InputDecoration(labelText: 'Nama Metode'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Aktif'),
                      value: isActive,
                      onChanged: (val) {
                        setStateInDialog(() => isActive = val);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  if (method == null) {
                    // Tambah baru
                    _dbService.addPaymentMethod(LocalPaymentMethod(
                      name: nameController.text,
                      isActive: isActive,
                    ));
                  } else {
                    // Update
                    method.name = nameController.text;
                    method.isActive = isActive;
                    _dbService.updatePaymentMethod(method.key, method);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(LocalPaymentMethod method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        title: const Text('Hapus Metode?'),
        content: Text(
            'Anda yakin ingin menghapus metode pembayaran "${method.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _dbService.deletePaymentMethod(method.key);
              Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Manajemen Metode Pembayaran'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder<Box<LocalPaymentMethod>>(
        valueListenable: _dbService.getPaymentMethodsListenable(),
        builder: (context, box, _) {
          final methods = box.values.toList().cast<LocalPaymentMethod>();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final method = methods[index];
              return Card(
                color: Colors.black.withOpacity(0.2),
                child: ListTile(
                  title: Text(method.name),
                  subtitle: Text(
                    method.isActive ? 'Aktif' : 'Tidak Aktif',
                    style: TextStyle(
                      color: method.isActive
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.amber),
                        onPressed: () => _showAddEditDialog(method: method),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _showDeleteDialog(method),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
