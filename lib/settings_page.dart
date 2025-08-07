import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _hourRateController = TextEditingController();
  final _minuteRateController = TextEditingController();
  final _shift1StartController = TextEditingController(); // Input baru
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _hourRateController.text = (prefs.getDouble('ratePerHour') ?? 50000)
        .toStringAsFixed(0);
    _minuteRateController.text = (prefs.getDouble('ratePerMinute') ?? 0)
        .toStringAsFixed(0);
    _shift1StartController.text = (prefs.getInt('shift1StartHour') ?? 8)
        .toString(); // Default jam 8 pagi
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
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Pengaturan berhasil disimpan!'),
        ),
      );
      Navigator.pop(context, true);
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
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Tarif Harga',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Tarif per Jam',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hourRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 50000',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tarif per Menit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _minuteRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 1000',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Pengaturan Shift',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Jam Mulai Shift 1 (0-23)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _shift1StartController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 8 (untuk jam 8 pagi)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Pengaturan'),
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
    );
  }
}
