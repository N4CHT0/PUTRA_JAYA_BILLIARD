import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:intl/intl.dart' as intl;

// Konstanta
const int NUM_RELAYS = 8;
final Map<int, int> relayPinMapping = {
  1: 2,
  2: 3,
  3: 4,
  4: 5,
  5: 6,
  6: 7,
  7: 8,
  8: 9,
};

// State Model
enum RelayStatus { Off, On, Timer }

class RelayData {
  final int id;
  RelayStatus status;
  int remainingTimeSeconds;
  DateTime? timerEndTime;
  bool fiveMinuteWarningSent;

  RelayData({
    required this.id,
    this.status = RelayStatus.Off,
    this.remainingTimeSeconds = 0,
    this.timerEndTime,
    this.fiveMinuteWarningSent = false,
  });
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
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  // Serial Port State
  List<String> _availablePorts = [];
  SerialPort? _port;
  StreamSubscription<Uint8List>? _serialSubscription;
  bool _isConnected = false;

  // App State
  final Map<int, RelayData> _relayStates = {};
  Timer? _logicTimer;
  final ScrollController _logScrollController = ScrollController();
  String _logMessages = '';

  @override
  void initState() {
    super.initState();
    _initRelayStates();
    _initPorts();
    _startLogicTimer();
  }

  @override
  void dispose() {
    _disconnectSerialPort();
    _logicTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _initRelayStates() {
    for (int i = 1; i <= NUM_RELAYS; i++) {
      _relayStates[i] = RelayData(id: i);
    }
  }

  // --- Jantung Aplikasi: Timer yang Optimal ---
  void _startLogicTimer() {
    _logicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final currentTime = DateTime.now();
      final List<int> finishedTimerIds = [];
      bool hasActiveTimers = false;

      // 1. Periksa setiap relay
      _relayStates.forEach((id, relay) {
        if (relay.status == RelayStatus.Timer && relay.timerEndTime != null) {
          hasActiveTimers = true;
          final remaining = relay.timerEndTime!
              .difference(currentTime)
              .inSeconds;
          relay.remainingTimeSeconds = remaining > 0 ? remaining : 0;

          if (relay.remainingTimeSeconds <= 0) {
            finishedTimerIds.add(id); // Kumpulkan ID timer yang selesai
          } else if (relay.remainingTimeSeconds <= 300 &&
              !relay.fiveMinuteWarningSent) {
            _addLog('Peringatan 5 menit Meja $id. Mengirim sinyal kedip.');
            relay.fiveMinuteWarningSent = true;
            _sendCommand(id, "BLINK");
          }
        }
      });

      // 2. Proses semua timer yang selesai
      if (finishedTimerIds.isNotEmpty) {
        for (final id in finishedTimerIds) {
          _handleTimerFinished(id);
        }
      }

      // 3. Update UI jika diperlukan
      if (hasActiveTimers || finishedTimerIds.isNotEmpty) {
        setState(() {});
      }
    });
  }

  void _handleTimerFinished(int mejaId) {
    _addLog('Waktu Meja $mejaId habis. Mereset & mematikan relay.');
    final relay = _relayStates[mejaId]!;

    // Reset state di aplikasi
    relay.status = RelayStatus.Off;
    relay.timerEndTime = null;
    relay.remainingTimeSeconds = 0;
    relay.fiveMinuteWarningSent = false;

    // Kirim perintah OFF ke Arduino
    _sendCommand(mejaId, "0");
  }

  // --- Fungsi Komunikasi Serial ---
  void _initPorts() {
    setState(() => _availablePorts = SerialPort.availablePorts);
  }

  Future<void> _connectSerialPort(String portName) async {
    await _disconnectSerialPort();
    _port = SerialPort(portName);
    try {
      if (!_port!.openReadWrite()) {
        throw SerialPortError(
          "Gagal membuka port: ${SerialPort.lastError?.toString()}",
        );
      }
      _port!.config = SerialPortConfig()
        // !!! PERBAIKAN KRUSIAL DI SINI !!!
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      final reader = SerialPortReader(_port!);
      _serialSubscription = reader.stream.listen((data) {
        final response = String.fromCharCodes(data).trim();
        if (response.isNotEmpty) {
          _addLog('Arduino: $response');
        }
      });

      setState(() => _isConnected = true);
      _addLog('Berhasil terhubung ke $portName');
    } on SerialPortError catch (e) {
      _addLog('Gagal terhubung: ${e.message}');
      await _disconnectSerialPort();
    }
  }

  Future<void> _disconnectSerialPort() async {
    await _serialSubscription?.cancel();
    _serialSubscription = null;
    if (_port != null && _port!.isOpen) {
      _port!.close();
      //_port!.dispose(); // Note: dispose bisa menyebabkan error di beberapa platform
      _port = null;
    }
    if (mounted) {
      setState(() => _isConnected = false);
      _addLog('Koneksi terputus.');
    }
  }

  Future<void> _sendCommand(int mejaId, String action) async {
    if (!_isConnected || _port == null) {
      _addLog('Error: Tidak terhubung ke Arduino.');
      return;
    }
    final int? pin = relayPinMapping[mejaId];
    if (pin == null) {
      _addLog('Error: Mapping pin untuk meja $mejaId tidak ditemukan.');
      return;
    }
    final command = '$pin,$action\n';
    try {
      _port!.write(Uint8List.fromList(command.codeUnits));
      _addLog('Mengirim: ${command.trim()}\\n');
    } on SerialPortError catch (e) {
      _addLog('Error mengirim perintah: ${e.message}');
    }
  }

  // --- Fungsi Aksi & UI ---
  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      final timestamp = intl.DateFormat('HH:mm:ss').format(DateTime.now());
      _logMessages = '$timestamp - $message\n$_logMessages';
      if (_logMessages.length > 3000) {
        // Increased log size
        _logMessages = _logMessages.substring(0, 3000);
      }
    });
    if (_logScrollController.hasClients) {
      _logScrollController.jumpTo(0);
    }
  }

  void _turnOnRelay(int mejaId) {
    _addLog('Meja $mejaId: Mode Personal (ON)');
    setState(() {
      _relayStates[mejaId]!.status = RelayStatus.On;
      _relayStates[mejaId]!.timerEndTime = null;
      _relayStates[mejaId]!.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "1");
  }

  void _turnOffRelay(int mejaId) {
    _addLog('Meja $mejaId: Dimatikan (OFF)');
    setState(() {
      _relayStates[mejaId]!.status = RelayStatus.Off;
      _relayStates[mejaId]!.timerEndTime = null;
      _relayStates[mejaId]!.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "0");
  }

  void _startTimer(int mejaId, int totalSeconds) {
    _addLog('Meja $mejaId: Timer dimulai (${_formatTime(totalSeconds)})');
    setState(() {
      final relay = _relayStates[mejaId]!;
      relay.status = RelayStatus.Timer;
      relay.timerEndTime = DateTime.now().add(Duration(seconds: totalSeconds));
      relay.remainingTimeSeconds = totalSeconds;
      relay.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "1");
  }

  Future<void> _showSetTimerDialog(int mejaId) async {
    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Atur Timer Meja $mejaId'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jam',
                  hintText: 'Contoh: 1',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Menit',
                  hintText: 'Contoh: 30',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Atur Timer'),
              onPressed: () {
                final hours = int.tryParse(hoursController.text) ?? 0;
                final minutes = int.tryParse(minutesController.text) ?? 0;
                final totalSeconds = (hours * 3600) + (minutes * 60);
                if (totalSeconds > 0) {
                  _startTimer(mejaId, totalSeconds);
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
        title: const Text('Kontrol Relay Billiard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isConnected ? null : _initPorts,
            tooltip: 'Refresh Port List',
          ),
          if (!_isConnected)
            DropdownButton<String>(
              value: null,
              hint: const Text('Pilih Port'),
              items: _availablePorts.map<DropdownMenuItem<String>>((
                String port,
              ) {
                return DropdownMenuItem<String>(value: port, child: Text(port));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) _connectSerialPort(newValue);
              },
            ),
          const SizedBox(width: 10),
          if (_isConnected)
            ElevatedButton.icon(
              onPressed: _disconnectSerialPort,
              icon: const Icon(Icons.close),
              label: Text('Disconnect ${_port?.name ?? ""}'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          const SizedBox(width: 10),
        ],
      ),
      // --- PERUBAHAN TATA LETAK UTAMA DIMULAI DI SINI ---
      body: Column(
        // 1. Diubah dari Row ke Column
        children: [
          Expanded(
            // 2. Panel GridView (atas) mengambil 95% layar
            flex: 9, // = 95%
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
                      statusText = 'ON (Personal)';
                      cardColor = Colors.green.shade900;
                      break;
                    case RelayStatus.Off:
                      statusText = 'OFF';
                      cardColor = Colors.grey.shade800;
                      break;
                    case RelayStatus.Timer:
                      statusText =
                          'TIMER: ${_formatTime(relay.remainingTimeSeconds)}';
                      cardColor =
                          relay.remainingTimeSeconds <= 300 &&
                              relay.remainingTimeSeconds > 0
                          ? Colors.deepPurple.shade900
                          : Colors.orange.shade900;
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
                                color: Colors.redAccent,
                                iconSize: 30,
                                tooltip: 'Matikan',
                                onPressed: () => _turnOffRelay(mejaId),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                color: Colors.lightGreenAccent,
                                iconSize: 30,
                                tooltip: 'Nyalakan (Personal)',
                                onPressed: () => _turnOnRelay(mejaId),
                              ),
                              IconButton(
                                icon: const Icon(Icons.timer),
                                color: Colors.orangeAccent,
                                iconSize: 30,
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
          // 3. Panel Log (bawah) mengambil 5% layar
          Expanded(
            flex: 1, // = 5%
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Log Komunikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _logMessages = ''),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _logScrollController,
                      reverse: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _logMessages,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10, // Font diperkecil agar muat
                          ),
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
