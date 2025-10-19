// lib/pages/settings/settings_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onSaveComplete;
  const SettingsPage({super.key, required this.onSaveComplete});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // === Kontroler BARU ===
  // Global
  final _nightRateStartController = TextEditingController();

  // Weekday (Siang & Malam)
  final _weekdayDayHourRateController = TextEditingController();
  final _weekdayNightHourRateController = TextEditingController();

  // Weekend (Siang & Malam)
  final _weekendDayHourRateController = TextEditingController();
  final _weekendNightHourRateController = TextEditingController();

  // Special Day (Siang & Malam)
  final _specialDayHourRateController = TextEditingController();
  final _specialNightHourRateController = TextEditingController();

  // Shift (Tetap sama)
  final _shift1StartController = TextEditingController();

  List<DateTime> _specialDates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // DIUBAH: Memuat semua pengaturan dengan struktur baru
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // Global
    _nightRateStartController.text = (prefs.getInt('nightRateStartHour') ?? 22)
        .toString(); // Default jam 10 malam

    // Weekday
    _weekdayDayHourRateController.text =
        (prefs.getDouble('weekday_day_rate_per_hour') ?? 50000)
            .toStringAsFixed(0);
    _weekdayNightHourRateController.text =
        (prefs.getDouble('weekday_night_rate_per_hour') ?? 60000)
            .toStringAsFixed(0);

    // Weekend
    _weekendDayHourRateController.text =
        (prefs.getDouble('weekend_day_rate_per_hour') ?? 65000)
            .toStringAsFixed(0);
    _weekendNightHourRateController.text =
        (prefs.getDouble('weekend_night_rate_per_hour') ?? 75000)
            .toStringAsFixed(0);

    // Special Day
    _specialDayHourRateController.text =
        (prefs.getDouble('special_day_rate_per_hour') ?? 80000)
            .toStringAsFixed(0);
    _specialNightHourRateController.text =
        (prefs.getDouble('special_night_rate_per_hour') ?? 90000)
            .toStringAsFixed(0);

    // Tanggal Spesial & Shift (Tetap sama)
    final dateStrings = prefs.getStringList('specialDates') ?? [];
    _specialDates = dateStrings.map((date) => DateTime.parse(date)).toList();
    _shift1StartController.text =
        (prefs.getInt('shift1StartHour') ?? 8).toString();

    setState(() => _isLoading = false);
  }

  // DIUBAH: Menyimpan semua pengaturan dengan struktur baru
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Global
    await prefs.setInt('nightRateStartHour',
        int.tryParse(_nightRateStartController.text) ?? 22);

    // Weekday
    await prefs.setDouble('weekday_day_rate_per_hour',
        double.tryParse(_weekdayDayHourRateController.text) ?? 0);
    await prefs.setDouble('weekday_night_rate_per_hour',
        double.tryParse(_weekdayNightHourRateController.text) ?? 0);

    // Weekend
    await prefs.setDouble('weekend_day_rate_per_hour',
        double.tryParse(_weekendDayHourRateController.text) ?? 0);
    await prefs.setDouble('weekend_night_rate_per_hour',
        double.tryParse(_weekendNightHourRateController.text) ?? 0);

    // Special Day
    await prefs.setDouble('special_day_rate_per_hour',
        double.tryParse(_specialDayHourRateController.text) ?? 0);
    await prefs.setDouble('special_night_rate_per_hour',
        double.tryParse(_specialNightHourRateController.text) ?? 0);

    // Tanggal Spesial & Shift (Tetap sama)
    final dateStrings =
        _specialDates.map((date) => date.toIso8601String()).toList();
    await prefs.setStringList('specialDates', dateStrings);
    await prefs.setInt(
        'shift1StartHour', int.tryParse(_shift1StartController.text) ?? 8);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[800],
        content: const Text(
          'Pengaturan berhasil disimpan!',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    widget.onSaveComplete();
  }

  @override
  void dispose() {
    _nightRateStartController.dispose();
    _weekdayDayHourRateController.dispose();
    _weekdayNightHourRateController.dispose();
    _weekendDayHourRateController.dispose();
    _weekendNightHourRateController.dispose();
    _specialDayHourRateController.dispose();
    _specialNightHourRateController.dispose();
    _shift1StartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                // --- BAGIAN BARU: PENGATURAN WAKTU TARIF ---
                _buildSectionTitle('Pengaturan Waktu Tarif'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nightRateStartController,
                  labelText: 'Jam Mulai Tarif Malam (0-23)',
                  hintText: 'Contoh: 22 (untuk jam 10 malam)',
                ),
                const SizedBox(height: 48),

                // --- BAGIAN TARIF DI-RESTRUKTURISASI ---
                _buildSectionTitle('Tarif Weekday (Senin - Jumat)'),
                _buildRateCard(
                  title: 'Tarif Siang',
                  hourController: _weekdayDayHourRateController,
                ),
                _buildRateCard(
                  title: 'Tarif Malam',
                  hourController: _weekdayNightHourRateController,
                ),
                const SizedBox(height: 48),

                _buildSectionTitle('Tarif Weekend (Sabtu - Minggu)'),
                _buildRateCard(
                  title: 'Tarif Siang',
                  hourController: _weekendDayHourRateController,
                ),
                _buildRateCard(
                  title: 'Tarif Malam',
                  hourController: _weekendNightHourRateController,
                ),
                const SizedBox(height: 48),

                _buildSectionTitle('Tarif Hari Spesial (Libur Nasional, dll)'),
                _buildRateCard(
                  title: 'Tarif Siang',
                  hourController: _specialDayHourRateController,
                ),
                _buildRateCard(
                  title: 'Tarif Malam',
                  hourController: _specialNightHourRateController,
                ),
                const SizedBox(height: 48),

                // --- BAGIAN TANGGAL SPESIAL & SHIFT (Tampilan tetap sama) ---
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
                      label: Text(DateFormat('dd MMM yyyy').format(date)),
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

                // Tombol Simpan
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

  // WIDGET BARU: untuk menampilkan grup tarif (siang/malam)
  Widget _buildRateCard(
      {required String title, required TextEditingController hourController}) {
    return Card(
      color: Colors.black.withOpacity(0.15),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildTextField(
              controller: hourController,
              labelText: 'Tarif per Jam',
              prefixText: 'Rp ',
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi dan widget helper lainnya (tidak ada perubahan)
  Future<void> _pickSpecialDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
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
          _specialDates.sort();
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
