import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  // --- PERUBAHAN 1: Tambahkan callback function ---
  final VoidCallback onSaveComplete;

  const SettingsPage({super.key, required this.onSaveComplete});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _hourRateController = TextEditingController();
  final _minuteRateController = TextEditingController();
  final _shift1StartController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _hourRateController.text =
        (prefs.getDouble('ratePerHour') ?? 50000).toStringAsFixed(0);
    _minuteRateController.text =
        (prefs.getDouble('ratePerMinute') ?? 0).toStringAsFixed(0);
    _shift1StartController.text =
        (prefs.getInt('shift1StartHour') ?? 8).toString();
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hourRate = double.tryParse(_hourRateController.text) ?? 0;
    final minuteRate = double.tryParse(_minuteRateController.text) ?? 0;
    final shift1Start = int.tryParse(_shift1StartController.text) ?? 8;

    await prefs.setDouble('ratePerHour', hourRate);
    await prefs.setDouble('ratePerMinute', minuteRate);
    await prefs.setInt('shift1StartHour', shift1Start);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: const Text(
            'Pengaturan berhasil disimpan!',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      // --- PERUBAHAN 2: Ganti Navigator.pop dengan memanggil callback ---
      widget.onSaveComplete();
    }
  }

  @override
  void dispose() {
    _hourRateController.dispose();
    _minuteRateController.dispose();
    _shift1StartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildSectionTitle('Tarif Harga'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _hourRateController,
                  labelText: 'Tarif per Jam',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _minuteRateController,
                  labelText: 'Tarif per Menit',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 48),
                _buildSectionTitle('Pengaturan Shift'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _shift1StartController,
                  labelText: 'Jam Mulai Shift 1 (0-23)',
                  hintText: 'Contoh: 8 (untuk jam 8 pagi)',
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Pengaturan'),
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.white.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        prefixText: prefixText,
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent),
        ),
      ),
    );
  }
}
