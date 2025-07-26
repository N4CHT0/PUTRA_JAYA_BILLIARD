import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';
// Mengimpor paket intl dengan prefix 'intl' untuk menghindari ambiguitas
import 'package:intl/intl.dart' as intl;
// Import yang dibutuhkan untuk komunikasi serial
import 'package:flutter_libserialport/flutter_libserialport.dart';

// Konstanta jumlah relay, diletakkan di atas agar mudah diakses
const int NUM_RELAYS = 8;

// Enum untuk status relay agar kode lebih mudah dibaca
enum RelayStatus { Off, On, Timer }

// Kelas untuk menyimpan state setiap relay
class RelayData {
  final int id;
  RelayStatus status;
  int remainingTimeSeconds;
  DateTime? timerEndTime;

  RelayData({
    required this.id,
    this.status = RelayStatus.Off,
    this.remainingTimeSeconds = 0,
    this.timerEndTime,
  });

  // Factory untuk membuat RelayData dari string yang diterima dari Arduino
  // Format: "ID,STATUS,NILAI" (Contoh: "1,TIMER,3600")
  factory RelayData.fromString(String data) {
    final parts = data.split(',');
    if (parts.length != 3) {
      throw FormatException('Format data serial tidak valid: $data');
    }

    final id = int.parse(parts[0]);
    final statusString = parts[1].toUpperCase();
    final value = int.parse(parts[2]);

    RelayStatus status;
    int remainingTime = 0;
    DateTime? endTime;

    switch (statusString) {
      case "ON":
        status = RelayStatus.On;
        break;
      case "OFF":
        status = RelayStatus.Off;
        break;
      case "TIMER":
        status = RelayStatus.Timer;
        remainingTime = value;
        // Jika value > 0, set waktu berakhirnya
        if (value > 0) {
          endTime = DateTime.now().add(Duration(seconds: value));
        }
        break;
      default:
        status = RelayStatus.Off; // Default jika status tidak dikenal
    }

    return RelayData(
      id: id,
      status: status,
      remainingTimeSeconds: remainingTime,
      timerEndTime: endTime,
    );
  }

  // Metode untuk mengupdate data relay yang sudah ada
  void update(RelayData newData) {
    status = newData.status;
    remainingTimeSeconds = newData.remainingTimeSeconds;
    timerEndTime = newData.timerEndTime;
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arduino Relay Control',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _availablePorts = [];
  SerialPort? _port;
  late SerialPortReader _reader;
  bool _isConnected = false;
  final ScrollController _logScrollController = ScrollController();
  String _logMessages = '';

  final Map<int, RelayData> _relayStates = {};
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initRelayStates();
    _initPorts();
    _startUiUpdateTimer();
  }

  @override
  void dispose() {
    _disconnectSerialPort();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _initRelayStates() {
    for (int i = 1; i <= NUM_RELAYS; i++) {
      _relayStates[i] = RelayData(id: i);
    }
  }

  void _startUiUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _relayStates.forEach((id, relay) {
          if (relay.status == RelayStatus.Timer && relay.timerEndTime != null) {
            final remaining = relay.timerEndTime!
                .difference(DateTime.now())
                .inSeconds;
            relay.remainingTimeSeconds = remaining > 0 ? remaining : 0;
            if (remaining <= 0) {
              relay.status = RelayStatus.Off;
              relay.timerEndTime = null;
              _addLog('Meja $id: Timer selesai.');
            }
          }
        });
      });
    });
  }

  void _initPorts() {
    setState(() => _availablePorts = SerialPort.availablePorts);
  }

  Future<void> _connectSerialPort(String portName) async {
    _disconnectSerialPort(); // Pastikan port lama sudah ditutup
    setState(() {
      _port = SerialPort(portName);
    });

    try {
      if (!_port!.openReadWrite()) {
        throw SerialPortError("Gagal membuka port: ${SerialPort.lastError}");
      }

      _port!.config = SerialPortConfig()
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      _reader = SerialPortReader(_port!);
      _listenForSerialData();

      setState(() {
        _isConnected = true;
      });
      _addLog('Berhasil terhubung ke ${portName}');
      _sendCommand(0, 'STATUS', 0); // Minta status awal dari semua relay
    } on SerialPortError catch (e) {
      _addLog('Gagal terhubung: ${e.message}');
      _disconnectSerialPort();
    }
  }

  void _disconnectSerialPort() {
    if (_port != null) {
      _port!.close();
      _port!.dispose();
      _port = null;
      setState(() {
        _isConnected = false;
      });
      _addLog('Koneksi terputus.');
    }
  }

  void _listenForSerialData() {
    _reader.stream.listen(
      (data) {
        final receivedString = String.fromCharCodes(data).trim();
        if (receivedString.isNotEmpty) {
          _addLog('Diterima: $receivedString');
          try {
            final newRelayData = RelayData.fromString(receivedString);
            if (_relayStates.containsKey(newRelayData.id)) {
              setState(() {
                _relayStates[newRelayData.id]!.update(newRelayData);
              });
            }
          } catch (e) {
            _addLog('Error parsing data: $e - Data: "$receivedString"');
          }
        }
      },
      onError: (error) {
        _addLog('Serial read error: $error');
        _disconnectSerialPort();
      },
      onDone: () {
        _disconnectSerialPort();
      },
    );
  }

  Future<void> _sendCommand(int mejaId, String action, int value) async {
    if (!_isConnected || _port == null) {
      _addLog('Tidak terhubung ke Arduino.');
      return;
    }

    final command = '$mejaId,$action,$value\n';
    try {
      final bytesWritten = _port!.write(Uint8List.fromList(command.codeUnits));
      if (bytesWritten != command.length) {
        _addLog('Error: Gagal mengirim seluruh data. Terkirim: $bytesWritten');
      }
      _addLog('Mengirim: $command');
    } on SerialPortError catch (e) {
      _addLog('Error mengirim perintah: ${e.message}');
    }
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      // PERBAIKAN: Menggunakan prefix 'intl' untuk memanggil DateFormat
      _logMessages =
          '${intl.DateFormat('HH:mm:ss').format(DateTime.now())} - $message\n$_logMessages';
      if (_logMessages.length > 2000) {
        _logMessages = _logMessages.substring(0, 2000);
      }
    });
    // Auto-scroll log
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showSetTimerDialog(int mejaId) async {
    final timerController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Atur Timer Meja $mejaId'),
          content: TextField(
            controller: timerController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Durasi (detik)',
              hintText: 'Contoh: 3600 (untuk 1 jam)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Atur'),
              onPressed: () {
                final duration = int.tryParse(timerController.text);
                if (duration != null && duration > 0) {
                  _sendCommand(mejaId, 'TIMER', duration);
                  Navigator.of(context).pop();
                } else {
                  _addLog('Input durasi tidak valid.');
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Relay (USB)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initPorts,
            tooltip: 'Refresh Port List',
          ),
          if (!_isConnected)
            DropdownButton<String>(
              value: _port?.name,
              hint: const Text('Pilih Port'),
              items: _availablePorts.map<DropdownMenuItem<String>>((
                String port,
              ) {
                return DropdownMenuItem<String>(value: port, child: Text(port));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _connectSerialPort(newValue);
                }
              },
            ),
          const SizedBox(width: 10),
          if (_isConnected)
            ElevatedButton.icon(
              onPressed: _disconnectSerialPort,
              icon: const Icon(Icons.close),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          // Kolom utama untuk kartu relay
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: NUM_RELAYS,
                itemBuilder: (context, index) {
                  final mejaId = index + 1;
                  final relay = _relayStates[mejaId]!;
                  String statusText;
                  Color cardColor;

                  switch (relay.status) {
                    case RelayStatus.On:
                      statusText = 'ON';
                      cardColor = Colors.green.shade900;
                      break;
                    case RelayStatus.Off:
                      statusText = 'OFF';
                      cardColor = Colors.grey.shade800;
                      break;
                    case RelayStatus.Timer:
                      statusText =
                          'TIMER: ${_formatTime(relay.remainingTimeSeconds)}';
                      cardColor = Colors.orange.shade900;
                      break;
                  }

                  return Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Meja $mejaId',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            'Status: $statusText',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.power_settings_new),
                                color: Colors.red,
                                tooltip: 'Matikan',
                                onPressed: () => _sendCommand(mejaId, 'OFF', 0),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                color: Colors.green,
                                tooltip: 'Nyalakan',
                                onPressed: () => _sendCommand(mejaId, 'ON', 0),
                              ),
                              IconButton(
                                icon: const Icon(Icons.timer),
                                color: Colors.orange,
                                tooltip: 'Set Timer',
                                onPressed: () => _showSetTimerDialog(mejaId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Kolom untuk log
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Log Komunikasi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _logMessages = ''),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _logScrollController,
                      reverse: true, // Agar log terbaru di bawah
                      child: Text(
                        _logMessages,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
