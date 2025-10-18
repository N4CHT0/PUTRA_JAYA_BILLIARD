// lib/pages/settings/settings_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onSaveComplete; // Callback saat simpan selesai
  const SettingsPage({super.key, required this.onSaveComplete});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- Kontroler untuk 3 set tarif ---
  final _weekdayHourRateController = TextEditingController();
  final _weekdayMinuteRateController = TextEditingController();
  final _weekendHourRateController = TextEditingController();
  final _weekendMinuteRateController = TextEditingController();
  final _specialDayHourRateController = TextEditingController();
  final _specialDayMinuteRateController = TextEditingController();

  final _shift1StartController = TextEditingController(); // Kontroler Shift

  // --- State untuk daftar tanggal spesial ---
  List<DateTime> _specialDates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Memuat semua pengaturan dari SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    _weekdayHourRateController.text =
        (prefs.getDouble('weekdayRatePerHour') ?? 50000).toStringAsFixed(0);
    _weekdayMinuteRateController.text =
        (prefs.getDouble('weekdayRatePerMinute') ?? 0).toStringAsFixed(0);

    _weekendHourRateController.text =
        (prefs.getDouble('weekendRatePerHour') ?? 65000).toStringAsFixed(0);
    _weekendMinuteRateController.text =
        (prefs.getDouble('weekendRatePerMinute') ?? 0).toStringAsFixed(0);

    _specialDayHourRateController.text =
        (prefs.getDouble('specialDayRatePerHour') ?? 80000).toStringAsFixed(0);
    _specialDayMinuteRateController.text =
        (prefs.getDouble('specialDayRatePerMinute') ?? 0).toStringAsFixed(0);

    final dateStrings = prefs.getStringList('specialDates') ?? [];
    _specialDates = dateStrings.map((date) => DateTime.parse(date)).toList();

    _shift1StartController.text =
        (prefs.getInt('shift1StartHour') ?? 8).toString();

    setState(() => _isLoading = false);
  }

  // Menyimpan semua pengaturan ke SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('weekdayRatePerHour',
        double.tryParse(_weekdayHourRateController.text) ?? 0);
    await prefs.setDouble('weekdayRatePerMinute',
        double.tryParse(_weekdayMinuteRateController.text) ?? 0);

    await prefs.setDouble('weekendRatePerHour',
        double.tryParse(_weekendHourRateController.text) ?? 0);
    await prefs.setDouble('weekendRatePerMinute',
        double.tryParse(_weekendMinuteRateController.text) ?? 0);

    await prefs.setDouble('specialDayRatePerHour',
        double.tryParse(_specialDayHourRateController.text) ?? 0);
    await prefs.setDouble('specialDayRatePerMinute',
        double.tryParse(_specialDayMinuteRateController.text) ?? 0);

    final dateStrings =
        _specialDates.map((date) => date.toIso8601String()).toList();
    await prefs.setStringList('specialDates', dateStrings);

    await prefs.setInt(
        'shift1StartHour', int.tryParse(_shift1StartController.text) ?? 8);

    if (!mounted) return; // Mounted check sebelum panggil context
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[800],
        content: const Text(
          'Pengaturan berhasil disimpan!',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    widget.onSaveComplete(); // Panggil callback untuk kembali ke Dashboard
  }

  @override
  void dispose() {
    _weekdayHourRateController.dispose();
    _weekdayMinuteRateController.dispose();
    _weekendHourRateController.dispose();
    _weekendMinuteRateController.dispose();
    _specialDayHourRateController.dispose();
    _specialDayMinuteRateController.dispose();
    _shift1StartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Samakan dengan MainLayout
      appBar: AppBar(
        title: const Text('Pengaturan Tarif & Shift'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildSectionTitle('Tarif Weekday (Senin - Jumat)'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _weekdayHourRateController,
                  labelText: 'Tarif per Jam (Weekday)',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _weekdayMinuteRateController,
                  labelText: 'Tarif per Menit (Weekday)',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 48),
                _buildSectionTitle('Tarif Weekend (Sabtu - Minggu)'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _weekendHourRateController,
                  labelText: 'Tarif per Jam (Weekend)',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _weekendMinuteRateController,
                  labelText: 'Tarif per Menit (Weekend)',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 48),
                _buildSectionTitle('Tarif Hari Spesial (Libur Nasional, dll)'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _specialDayHourRateController,
                  labelText: 'Tarif per Jam (Spesial)',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _specialDayMinuteRateController,
                  labelText: 'Tarif per Menit (Spesial)',
                  prefixText: 'Rp ',
                ),
                const SizedBox(height: 48),
                _buildSectionTitle('Daftar Tanggal Hari Spesial'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Tambah Tanggal'),
                  onPressed: _pickSpecialDate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _specialDates.map((date) {
                    return Chip(
                      label: Text(
                        DateFormat('dd MMM yyyy').format(date),
                      ),
                      backgroundColor: Colors.teal,
                      deleteIconColor: Colors.white70,
                      onDeleted: () {
                        setState(() {
                          _specialDates.remove(date);
                        });
                      },
                    );
                  }).toList(),
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

  // Fungsi untuk memilih tanggal spesial
  Future<void> _pickSpecialDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate:
          DateTime.now().add(const Duration(days: 365 * 2)), // 2 tahun ke depan
      builder: (context, child) {
        // Optional: Theme gelap
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.tealAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final normalizedDate = DateTime(picked.year, picked.month, picked.day);
      if (!_specialDates.contains(normalizedDate)) {
        setState(() {
          _specialDates.add(normalizedDate);
          _specialDates.sort(); // Urutkan tanggal
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Tanggal tersebut sudah ada.'),
          ),
        );
      }
    }
  }

  // Helper widget untuk judul bagian
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

  // Helper widget untuk TextField
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
