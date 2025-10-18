import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';

class ConnectionSettingsPage extends StatefulWidget {
  const ConnectionSettingsPage({super.key});

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  // Gunakan satu instance ArduinoService yang sama dengan Dashboard
  // Ini penting agar status koneksi sinkron di seluruh aplikasi.
  final ArduinoService _arduinoService = ArduinoService();

  List<String> _availableArduinoPorts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshArduinoPorts();
  }

  Future<void> _refreshArduinoPorts() async {
    setState(() => _isLoading = true);
    // Beri jeda sedikit agar UI sempat update loading state
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _availableArduinoPorts = _arduinoService.getAvailablePorts();
      _isLoading = false;
    });
  }

  Future<void> _connectArduino(String port) async {
    await _arduinoService.connect(
      port,
      onConnected: () {
        if (!mounted) return;
        setState(() {}); // Update UI to show connected status
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil terhubung ke $port'),
            backgroundColor: Colors.green,
          ),
        );
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal terhubung: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _disconnectArduino() async {
    await _arduinoService.disconnect();
    if (!mounted) return;
    setState(() {}); // Update UI to show disconnected status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Koneksi berhasil diputus.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16213e),
      appBar: AppBar(
        title: const Text('Pengaturan Koneksi'),
        backgroundColor: const Color(0xFF1a1a2e),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildArduinoConnectionCard(),
            const SizedBox(height: 24),
            _buildPrinterConnectionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildArduinoConnectionCard() {
    final isConnected = _arduinoService.isConnected;

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kontroler Lampu (Arduino)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? 'Terhubung ke ${_arduinoService.connectedPortName}'
                      : 'Tidak Terhubung',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 32),
            if (!isConnected) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: null,
                      hint: const Text('Pilih Port Serial'),
                      items: _availableArduinoPorts
                          .map<DropdownMenuItem<String>>((String port) {
                        return DropdownMenuItem<String>(
                          value: port,
                          child: Text(port),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          _connectArduino(newValue);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshArduinoPorts,
                      tooltip: 'Refresh Daftar Port',
                    ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _disconnectArduino,
                  icon: const Icon(Icons.close),
                  label: const Text('Putuskan Koneksi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterConnectionCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printer Nota',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fitur koneksi printer akan tersedia di pembaruan selanjutnya.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
