import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

final Map<int, int> mejaToRelayMapping = {
  1: 1,
  2: 2,
  3: 3,
  4: 4,
  5: 5,
  6: 6,
  7: 7,
  8: 8,
  9: 9,
  10: 10,
  11: 11,
  12: 12,
  13: 13,
  14: 14,
  15: 15,
  16: 16,
  17: 17,
  18: 18,
  19: 19,
  20: 20,
  21: 21,
  22: 22,
  23: 23,
  24: 24,
  25: 25,
  26: 26,
  27: 27,
  28: 28,
  29: 29,
  30: 30,
  31: 31,
  32: 32,
};

class ArduinoService {
  SerialPort? _port;
  StreamSubscription<Uint8List>? _serialSubscription;
  VoidCallback? onConnectionChanged;
  Function(String)? onDataReceived;
  Timer? _monitorTimer;
  String? _lastConnectedPort;
  bool _isAttemptingReconnect = false;
  // ---------------------------------------------

  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  bool get isConnected => _port != null && _port!.isOpen;
  String? get connectedPortName => _port?.name;

  Future<void> connect(
    String portName, {
    required VoidCallback onConnected,
    required Function(String) onError,
  }) async {
    // Jika sedang mencoba reconnect, hentikan dulu
    if (_isAttemptingReconnect) return;

    await disconnect(); // Putuskan koneksi lama jika ada
    _port = SerialPort(portName);

    try {
      if (!_port!.openReadWrite()) {
        throw SerialPortError("Gagal membuka port.");
      }
      _port!.config = SerialPortConfig()
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      final reader = SerialPortReader(_port!);
      _serialSubscription = reader.stream.listen((data) {
        final response = String.fromCharCodes(data).trim();
        if (response.isNotEmpty) {
          onDataReceived?.call(response);
        }
      });

      // Simpan nama port yang berhasil terhubung & mulai monitoring
      _lastConnectedPort = portName;
      _startDisconnectionMonitor();

      onConnectionChanged?.call();
      onConnected();
    } on SerialPortError catch (e) {
      _lastConnectedPort = null;
      onError('Gagal terhubung: ${e.message}');
      await disconnect();
    }
  }

  Future<void> disconnect({bool isManual = true}) async {
    // Hentikan monitoring jika disconnect manual
    if (isManual) {
      _lastConnectedPort = null;
      _monitorTimer?.cancel();
    }

    await _serialSubscription?.cancel();
    _serialSubscription = null;

    if (_port != null && _port!.isOpen) {
      try {
        _port!.close();
      } catch (e) {
        print("Error saat menutup port: $e");
      }
    }
    _port = null;

    // Selalu panggil callback saat koneksi berubah
    onConnectionChanged?.call();
  }

  void _startDisconnectionMonitor() {
    _monitorTimer?.cancel(); // Hentikan timer lama jika ada
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_lastConnectedPort == null || _isAttemptingReconnect) {
        return; // Jangan lakukan apa-apa jika tidak ada port target atau sedang reconnect
      }

      // Cek apakah port yang terhubung masih ada di daftar port sistem
      final availablePorts = SerialPort.availablePorts;
      if (!availablePorts.contains(_lastConnectedPort)) {
        print(
            'Koneksi ke $_lastConnectedPort terputus! Mencoba menghubungkan kembali...');
        _handleAutoReconnect();
      }
    });
  }

  Future<void> _handleAutoReconnect() async {
    _isAttemptingReconnect = true;
    _monitorTimer?.cancel(); // Hentikan monitor sementara

    // Beri tahu UI bahwa koneksi terputus
    await disconnect(isManual: false);

    // Coba hubungkan kembali setiap 5 detik
    while (_lastConnectedPort != null) {
      await Future.delayed(const Duration(seconds: 5));

      // Cek lagi apakah port sudah muncul kembali
      if (!SerialPort.availablePorts.contains(_lastConnectedPort)) {
        print("Port $_lastConnectedPort masih belum tersedia, mencoba lagi...");
        continue; // Lanjut ke iterasi berikutnya
      }

      print("Port $_lastConnectedPort terdeteksi! Mencoba koneksi...");
      bool success = false;
      await connect(
        _lastConnectedPort!,
        onConnected: () {
          print("Berhasil terhubung kembali secara otomatis!");
          success = true;
        },
        onError: (error) {
          print("Gagal menyambung kembali: $error");
          success = false;
        },
      );

      if (success) {
        _isAttemptingReconnect = false;
        // Monitor sudah dimulai kembali dari dalam fungsi connect()
        break; // Keluar dari loop jika berhasil
      }
    }

    if (_lastConnectedPort == null) {
      // Jika disconnect manual terjadi saat reconnect, hentikan proses
      _isAttemptingReconnect = false;
    }
  }

  Future<bool> sendCommand(int mejaId, String action) async {
    if (!isConnected) return false;
    final int? relayNumber = mejaToRelayMapping[mejaId];
    if (relayNumber == null) {
      print("Error: Meja ID $mejaId tidak valid.");
      return false;
    }
    final command = '$relayNumber,$action\n';
    try {
      final bytesSent = _port!.write(Uint8List.fromList(command.codeUnits));
      if (bytesSent != command.length) {
        print('Error: Data tidak terkirim sepenuhnya.');
        return false;
      }
      print('Mengirim perintah: $command');
      return true;
    } catch (e) {
      print('Gagal mengirim perintah: $e');
      return false;
    }
  }

  void dispose() {
    _lastConnectedPort = null;
    _monitorTimer?.cancel();
    disconnect();
  }
}
