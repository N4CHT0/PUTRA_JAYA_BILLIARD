// lib/pages/connection/connection_page.dart

import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';
import 'package:putra_jaya_billiard/services/printer_service.dart';

class ConnectionPage extends StatefulWidget {
  final ArduinoService arduinoService;
  final PrinterService printerService;

  const ConnectionPage({
    super.key,
    required this.arduinoService,
    required this.printerService,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  List<String> _availablePorts = [];
  bool _isLoadingPanel = false;
  bool _isLoadingPrinter = false;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    widget.arduinoService.onConnectionChanged = () {
      if (mounted) setState(() {});
    };
    widget.printerService.onConnectionChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.arduinoService.onConnectionChanged = null;
    widget.printerService.onConnectionChanged = null;
    super.dispose();
  }

  Future<void> _refreshPorts() async {
    setState(() {
      _availablePorts = widget.arduinoService.getAvailablePorts();
    });
  }

  Future<void> _connect(String portName, {required bool isPrinter}) async {
    setState(() {
      if (isPrinter) {
        _isLoadingPrinter = true;
      } else {
        _isLoadingPanel = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menyambungkan ke $portName...')),
    );

    // FIX: Gunakan tipe dynamic agar bisa memanggil method connect dari kedua service
    final dynamic service =
        isPrinter ? widget.printerService : widget.arduinoService;

    await service.connect(
      portName,
      onConnected: () {
        if (!mounted) return;
        setState(() {
          if (isPrinter) {
            _isLoadingPrinter = false;
          } else {
            _isLoadingPanel = false;
          }
        });
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Berhasil terhubung!'),
              backgroundColor: Colors.green),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          if (isPrinter) {
            _isLoadingPrinter = false;
          } else {
            _isLoadingPanel = false;
          }
        });
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal terhubung: $error'),
              backgroundColor: Colors.red),
        );
      },
    );
  }

  Future<void> _disconnect({required bool isPrinter}) async {
    // FIX: Gunakan tipe dynamic agar bisa memanggil method disconnect dari kedua service
    final dynamic service =
        isPrinter ? widget.printerService : widget.arduinoService;
    await service.disconnect();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koneksi terputus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Koneksi'),
        backgroundColor: Colors.black26,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                (_isLoadingPanel || _isLoadingPrinter) ? null : _refreshPorts,
            tooltip: 'Refresh Port List',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Widget untuk Panel USB
            _buildConnectionCard(
              title: 'Panel USB',
              subtitle: '(Arduino Kontrol Meja)',
              service: widget.arduinoService,
              isLoading: _isLoadingPanel,
              onConnect: (port) => _connect(port, isPrinter: false),
              onDisconnect: () => _disconnect(isPrinter: false),
            ),
            const SizedBox(height: 24),
            // Widget untuk Printer USB
            _buildConnectionCard(
              title: 'Printer USB',
              subtitle: '(Struk & Laporan)',
              service: widget.printerService,
              isLoading: _isLoadingPrinter,
              onConnect: (port) => _connect(port, isPrinter: true),
              onDisconnect: () => _disconnect(isPrinter: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard({
    required String title,
    required String subtitle,
    // FIX: Ubah tipe dari ArduinoService menjadi dynamic
    required dynamic service,
    required bool isLoading,
    required Future<void> Function(String) onConnect,
    required Future<void> Function() onDisconnect,
  }) {
    final isConnected = service.isConnected;
    return Card(
      color: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 24),
            // Status Koneksi
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Terhubung ke: ${service.connectedPortName}'
                        : 'Tidak Terhubung',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Aksi
            if (!isConnected) ...[
              if (_availablePorts.isEmpty)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Tidak ada port serial yang ditemukan.'),
                )),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availablePorts.length,
                itemBuilder: (context, index) {
                  final port = _availablePorts[index];
                  return ListTile(
                    leading: const Icon(Icons.usb),
                    title: Text(port),
                    onTap: isLoading ? null : () => onConnect(port),
                  );
                },
              ),
              if (isLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: CircularProgressIndicator(),
                )),
            ],
            if (isConnected)
              ElevatedButton.icon(
                onPressed: onDisconnect,
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
