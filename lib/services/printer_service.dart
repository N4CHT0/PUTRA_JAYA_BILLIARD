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

  /// Contoh fungsi untuk mencetak struk sederhana.
  /// Anda dapat memodifikasi ini sesuai dengan format struk yang diinginkan.
  Future<void> printTestReceipt() async {
    if (!_isConnected) {
      print("Tidak bisa mencetak, printer tidak terhubung.");
      return;
    }

    // Contoh perintah ESC/POS
    List<int> commands = [];
    // Reset printer
    commands.addAll([0x1B, 0x40]);
    // Set alignment ke tengah
    commands.addAll([0x1B, 0x61, 1]);
    // Set teks tebal
    commands.addAll([0x1B, 0x45, 1]);
    commands.addAll('Putra Jaya Billiard\n'.codeUnits);
    // Matikan teks tebal
    commands.addAll([0x1B, 0x45, 0]);
    commands.addAll('--------------------------------\n'.codeUnits);
    // Set alignment ke kiri
    commands.addAll([0x1B, 0x61, 0]);
    commands.addAll('Item         Qty    Total\n'.codeUnits);
    commands.addAll('--------------------------------\n'.codeUnits);
    commands.addAll('Aqua Botol     1    Rp 5,000\n'.codeUnits);
    commands.addAll('Snack          2    Rp 10,000\n'.codeUnits);
    commands.addAll('\n\n'.codeUnits);
    // Set alignment ke tengah lagi
    commands.addAll([0x1B, 0x61, 1]);
    commands.addAll('Terima Kasih!\n'.codeUnits);
    // Cut paper (jika printer mendukung)
    commands.addAll([0x1D, 0x56, 1]);

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
