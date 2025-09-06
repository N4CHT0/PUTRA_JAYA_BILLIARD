import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'add_employee_page.dart';

class AccountsPage extends StatefulWidget {
  final UserModel admin;
  const AccountsPage({super.key, required this.admin});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showEditDialog(UserModel user) {
    final nameController = TextEditingController(text: user.nama);
    final roleController = TextEditingController(text: user.role);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Pegawai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 8),
              Text('Email & password tidak dapat diubah di sini.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateUser(user, nameController.text, roleController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUser(
      UserModel user, String newName, String newRole) async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'nama': newName,
        'role': newRole,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data berhasil diperbarui'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal memperbarui data: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteUser(String uid) async {
    try {
      // Menghapus data dari Firestore
      await _firestore.collection('users').doc(uid).delete();

      // PENTING: Menghapus user dari Firebase Auth harus dilakukan dari backend
      // (Cloud Function) untuk keamanan. Kode ini hanya menghapus dari database.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pegawai berhasil dihapus dari database'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal menghapus pegawai: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akun Pegawai'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada data pegawai.'));
          }

          final users = snapshot.data!.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(user.nama.isNotEmpty
                        ? user.nama[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(user.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Konfirmasi Hapus'),
                              content: Text(
                                  'Anda yakin ingin menghapus ${user.nama}? Akun Auth tidak akan terhapus.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  onPressed: () {
                                    _deleteUser(user.uid);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEmployeePage()),
          );
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
