import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class PrinterService with ChangeNotifier {
  SerialPort? _serialPort;
  bool _isConnected = false;
  String? _connectedPortName;
  SerialPortReader? _reader;

  // Callback untuk notifikasi perubahan koneksi
  VoidCallback? onConnectionChanged;

  /// Mendapatkan daftar semua port serial yang tersedia di sistem.
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// Status koneksi printer saat ini.
  bool get isConnected => _isConnected;

  /// Nama port yang sedang terhubung, misalnya 'COM3' atau '/dev/ttyUSB0'.
  String? get connectedPortName => _connectedPortName;

  /// Membuka koneksi ke printer melalui port serial yang ditentukan.
  ///
  /// [portName]: Nama port yang akan disambungkan.
  /// [onConnected]: Callback yang dieksekusi saat koneksi berhasil.
  /// [onError]: Callback yang dieksekusi jika terjadi kesalahan.
  Future<void> connect(
    String portName, {
    VoidCallback? onConnected,
    Function(String)? onError,
  }) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      _serialPort = SerialPort(portName);
      if (!_serialPort!.openReadWrite()) {
        final error = SerialPort.lastError;
        throw Exception(
            'Gagal membuka port: ${error?.message} (Code: ${error?.errorCode})');
      }

      // Konfigurasi umum untuk printer termal
      final config = SerialPortConfig();
      config.baudRate = 9600; // Baud rate umum untuk printer termal
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      _serialPort?.config = config;

      _isConnected = true;
      _connectedPortName = portName;
      _reader = SerialPortReader(_serialPort!);

      // Memberi notifikasi bahwa status koneksi berubah
      _notifyConnectionChange();
      onConnected?.call();
    } catch (e) {
      _isConnected = false;
      _connectedPortName = null;
      onError?.call(e.toString());
      _notifyConnectionChange();
    }
  }

  /// Menutup koneksi ke printer.
  Future<void> disconnect() async {
    if (_serialPort != null && _serialPort!.isOpen) {
      _reader?.close();
      _serialPort?.close();
      _serialPort?.dispose();
    }
    _serialPort = null;
    _reader = null;
    _isConnected = false;
    _connectedPortName = null;
    _notifyConnectionChange();
  }

  /// Mengirim data mentah (raw data) ke printer.
  ///
  /// Berguna untuk mengirim perintah ESC/POS dalam bentuk byte.
  Future<bool> sendRawData(Uint8List data) async {
    if (!_isConnected || _serialPort == null) {
      print('Printer tidak terhubung.');
      return false;
    }
    try {
      final bytesWritten = _serialPort!.write(data, timeout: 1000);
      return bytesWritten == data.length;
    } on SerialPortError catch (e, _) {
      print('Error saat mengirim data ke printer: ${e.message}');
      return false;
    }
  }

  // FUNGSI BARU: Untuk Test Print
  Future<void> printTestPage() async {
    if (!_isConnected) {
      print("Tidak bisa mencetak, printer tidak terhubung.");
      return;
    }

    List<int> commands = [];
    commands.addAll([0x1B, 0x40]); // Reset
    commands.addAll([0x1B, 0x61, 1]); // Align Center
    commands.addAll('Test Cetak Berhasil\n'.codeUnits);
    commands.addAll('Putra Jaya Billiard\n'.codeUnits);
    commands.addAll('================================\n'.codeUnits);
    commands.addAll([0x1B, 0x61, 0]); // Align Left
    commands.addAll('Koneksi printer OK.\n'.codeUnits);
    commands.addAll('Baud Rate: 9600\n'.codeUnits);
    commands.addAll('\n\n\n'.codeUnits);
    commands.addAll([0x1D, 0x56, 66, 0]); // Partial Cut

    await sendRawData(Uint8List.fromList(commands));
  }

  /// Membersihkan resource saat service tidak lagi digunakan.
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  /// Fungsi internal untuk memanggil listener/callback perubahan koneksi.
  void _notifyConnectionChange() {
    onConnectionChanged?.call();
    notifyListeners();
  }
}
