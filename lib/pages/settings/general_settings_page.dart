import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart'; // Ganti dengan path service Anda

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  final LocalDatabaseService _dbService = LocalDatabaseService();
  bool _isLoading = false;

  // Fungsi untuk menampilkan snackbar
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  // Fungsi untuk menampilkan dialog konfirmasi
  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: title.contains("Reset")
                    ? Colors.redAccent
                    : Colors.orangeAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(title.split(' ')[0]), // "Restore" atau "Reset"
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Aksi untuk Backup Data
  Future<void> _handleBackup() async {
    setState(() => _isLoading = true);
    try {
      final message = await _dbService.backupData();
      _showSnackbar(message);
    } catch (e) {
      _showSnackbar('Backup gagal: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Aksi untuk Restore Data
  Future<void> _handleRestore() async {
    final confirm = await _showConfirmationDialog('Restore Data?',
        'Aksi ini akan MENGGANTI semua data saat ini dengan data dari file backup. Anda yakin?');
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final message = await _dbService.restoreData();
      _showSnackbar(message);
    } catch (e) {
      _showSnackbar('Restore gagal: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Aksi untuk Import Data (Menambah)
  Future<void> _handleImport() async {
    setState(() => _isLoading = true);
    try {
      final message = await _dbService.importData();
      _showSnackbar(message);
    } catch (e) {
      _showSnackbar('Import gagal: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Aksi untuk Reset Data
  Future<void> _handleReset() async {
    final confirm = await _showConfirmationDialog('Reset Semua Data?',
        'PERINGATAN: Aksi ini akan MENGHAPUS SEMUA data lokal (produk, transaksi, member, dll.) secara permanen. Aksi ini tidak dapat dibatalkan.');
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _dbService.resetAllData();
      _showSnackbar('Semua data lokal berhasil direset.');
    } catch (e) {
      _showSnackbar('Reset gagal: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('General Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSettingsCard(
                icon: Icons.backup_rounded,
                title: 'Backup Data',
                subtitle:
                    'Simpan semua data lokal ke dalam satu file backup (.json).',
                onTap: _handleBackup,
                color: Colors.blueAccent,
              ),
              _buildSettingsCard(
                icon: Icons.restore_page_rounded,
                title: 'Restore Data',
                subtitle:
                    'Hapus data saat ini dan ganti dengan data dari file backup.',
                onTap: _handleRestore,
                color: Colors.orangeAccent,
              ),
              _buildSettingsCard(
                icon: Icons.move_to_inbox_rounded,
                title: 'Import Data',
                subtitle:
                    'Tambah data dari file tanpa menghapus data yang sudah ada.',
                onTap: _handleImport,
                color: Colors.greenAccent,
              ),
              _buildSettingsCard(
                icon: Icons.delete_forever_rounded,
                title: 'Reset Local Database',
                subtitle: 'Hapus semua data lokal untuk memulai dari awal.',
                onTap: _handleReset,
                color: Colors.redAccent,
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Memproses data...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      color: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 40, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: TextStyle(color: Colors.grey[400])),
        ),
        onTap: _isLoading ? null : onTap,
      ),
    );
  }
}
