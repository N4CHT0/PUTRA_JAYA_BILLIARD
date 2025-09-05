import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountsPage extends StatefulWidget {
  final UserModel admin;
  const AccountsPage({super.key, required this.admin});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> _callFunction(
      String name, Map<String, dynamic> params, String successMessage) async {
    // Fungsi helper untuk mengurangi duplikasi kode
    if (!mounted) return;
    try {
      final callable = _functions.httpsCallable(name);
      await callable.call(params);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _openFirebaseConsole() async {
    final Uri url = Uri.parse('https://console.firebase.google.com/');
    if (!await launchUrl(url)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka URL')),
      );
    }
  }

  void _showAccountDialog({UserModel? pegawai}) {
    final namaController = TextEditingController(text: pegawai?.nama ?? '');
    final emailController = TextEditingController(text: pegawai?.email ?? '');
    final passwordController = TextEditingController();
    final isEditing = pegawai != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Akun Pegawai' : 'Buat Akun Pegawai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- TAMBAHKAN INPUT NAMA ---
              TextField(
                  controller: namaController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap')),
              const SizedBox(height: 8),
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: isEditing ? 'Isi untuk mengubah' : '')),
            ],
          ),
          actions: [
            // ... (Tombol Batal dan Simpan)
            ElevatedButton(
              onPressed: () {
                // --- PERUBAHAN DI SINI ---
                final nama = namaController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (isEditing) {
                  // (Untuk edit, kita akan update Firestore saja, karena Cloud Function
                  // tidak kita buat untuk update nama demi simplicitas)
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(pegawai.uid)
                      .update({'nama': nama, 'email': email});
                } else {
                  // Saat membuat, kita akan kirim 'nama' ke Cloud Function
                  _callFunction(
                      'createPegawai',
                      {
                        'nama': nama, // <-- Kirim nama
                        'email': email,
                        'password': password,
                        'organisasi': widget.admin.organisasi,
                        'kodeOrganisasi': widget.admin.kodeOrganisasi,
                      },
                      'Akun berhasil dibuat!');
                }
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manajemen Akun ${widget.admin.organisasi}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Buka Firebase Console (Manual)',
            onPressed: _openFirebaseConsole,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('kodeOrganisasi', isEqualTo: widget.admin.kodeOrganisasi)
            .where('role', isEqualTo: 'pegawai')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada akun pegawai.'));
          }

          final pegawaiDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pegawaiDocs.length,
            itemBuilder: (context, index) {
              final doc = pegawaiDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final pegawai = UserModel(
                uid: doc.id,
                email: data['email'] ?? 'Email tidak ada',
                role: data['role'] ?? 'pegawai',
                organisasi: data['organisasi'] ?? 'Organisasi tidak ada',
                kodeOrganisasi: data['kodeOrganisasi'] ?? 'N/A',
                // --- PERUBAHAN DI SINI ---
                nama: data['nama'] ?? 'Tanpa Nama',
              );

              return ListTile(
                // --- PERUBAHAN DI SINI ---
                title: Text(pegawai.nama), // Tampilkan nama
                subtitle: Text(pegawai.email), // Email jadi subtitle
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.amber),
                      onPressed: () => _showAccountDialog(pegawai: pegawai),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _callFunction('deletePegawai',
                          {'uid': pegawai.uid}, 'Akun berhasil dihapus!'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Buat Akun Pegawai',
      ),
    );
  }
}
