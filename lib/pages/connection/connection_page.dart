// lib/pages/connection/connection_page.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';

class ConnectionPage extends StatefulWidget {
  final ArduinoService arduinoService;

  const ConnectionPage({
    super.key,
    required this.arduinoService,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  List<String> _availablePorts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    widget.arduinoService.onConnectionChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.arduinoService.onConnectionChanged = null;
    super.dispose();
  }

  Future<void> _refreshPorts() async {
    setState(() {
      _availablePorts = widget.arduinoService.getAvailablePorts();
    });
  }

  Future<void> _connect(String portName) async {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menyambungkan ke $portName...')),
    );

    await widget.arduinoService.connect(
      portName,
      onConnected: () {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Berhasil terhubung!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Go back to dashboard on success
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal terhubung: $error'),
              backgroundColor: Colors.red),
        );
      },
    );
  }

  Future<void> _disconnect() async {
    await widget.arduinoService.disconnect();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koneksi terputus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.arduinoService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Koneksi'),
        backgroundColor: Colors.black26,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.error,
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isConnected
                          ? 'Terhubung ke: ${widget.arduinoService.connectedPortName}'
                          : 'Tidak Terhubung',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!isConnected)
              Card(
                color: Colors.black.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih Port Tersedia',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_availablePorts.isEmpty)
                        const Center(
                            child:
                                Text('Tidak ada port serial yang ditemukan.')),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availablePorts.length,
                        itemBuilder: (context, index) {
                          final port = _availablePorts[index];
                          return ListTile(
                            leading: const Icon(Icons.usb),
                            title: Text(port),
                            onTap: _isLoading ? null : () => _connect(port),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : IconButton.filledTonal(
                                icon: const Icon(Icons.refresh),
                                onPressed: _refreshPorts,
                                tooltip: 'Refresh Port List',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            if (isConnected)
              ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.close),
                label: const Text('Putuskan Koneksi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
