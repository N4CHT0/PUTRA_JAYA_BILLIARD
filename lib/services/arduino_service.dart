import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

// Mapping dari ID Meja (1-32) ke nomor relay (1-32) yang akan dikirim ke Arduino Master.
// Arduino Master akan menentukan apakah perintah ini untuk dirinya atau untuk Slave.
final Map<int, int> mejaToRelayMapping = {
  // Relay yang terhubung ke Master (1-16)
  1: 1, 2: 2, 3: 3, 4: 4,
  5: 5, 6: 6, 7: 7, 8: 8,
  9: 9, 10: 10, 11: 11, 12: 12,
  13: 13, 14: 14, 15: 15, 16: 16,
  // Relay yang terhubung ke Slave (17-32)
  17: 17, 18: 18, 19: 19, 20: 20,
  21: 21, 22: 22, 23: 23, 24: 24,
  25: 25, 26: 26, 27: 27, 28: 28,
  29: 29, 30: 30, 31: 31, 32: 32,
};

class ArduinoService {
  SerialPort? _port;
  StreamSubscription<Uint8List>? _serialSubscription;
  Function(String)? onDataReceived;

  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  bool get isConnected => _port != null && _port!.isOpen;
  String? get connectedPortName => _port?.name;

  Future<void> connect(
    String portName, {
    required Function onConnected,
    required Function(String) onError,
  }) async {
    await disconnect();
    _port = SerialPort(portName);
    try {
      if (!_port!.openReadWrite()) {
        throw const SerialPortError("Gagal membuka port.");
      }
      // Pastikan baud rate cocok dengan Arduino Master
      _port!.config = SerialPortConfig()
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      final reader = SerialPortReader(_port!);
      _serialSubscription = reader.stream.listen((data) {
        final response = String.fromCharCodes(data).trim();
        if (response.isNotEmpty && onDataReceived != null) {
          onDataReceived!(response);
        }
      });
      onConnected();
    } on SerialPortError catch (e) {
      onError('Gagal terhubung: ${e.message}');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    await _serialSubscription?.cancel();
    _serialSubscription = null;
    if (_port != null && _port!.isOpen) {
      _port!.close();
      _port = null;
    }
  }

  /// Mengirim perintah ke Arduino Master.
  /// [mejaId] adalah ID meja dari 1 sampai 32.
  /// [action] adalah perintah, contoh: "1" (ON), "0" (OFF), atau "BLINK".
  Future<bool> sendCommand(int mejaId, String action) async {
    if (!isConnected) return false;

    // Dapatkan nomor relay dari mapping
    final int? relayNumber = mejaToRelayMapping[mejaId];
    if (relayNumber == null) {
      print("Error: Meja ID $mejaId tidak valid.");
      return false;
    }

    // Format perintah tetap sama: "nomor_relay,aksi\n"
    final command = '$relayNumber,$action\n';
    try {
      _port!.write(Uint8List.fromList(command.codeUnits));
      print('Mengirim perintah: $command'); // Untuk debugging
      return true;
    } catch (e) {
      print('Gagal mengirim perintah: $e');
      return false;
    }
  }

  void dispose() {
    disconnect();
  }
}
