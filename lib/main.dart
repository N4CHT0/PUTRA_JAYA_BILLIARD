import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/firebase_options.dart';
import 'package:putra_jaya_billiard/reports_page.dart';
import 'package:putra_jaya_billiard/settings_page.dart';
import 'package:putra_jaya_billiard/transactions_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

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
enum RelayStatus { Off, On, Timer, TimeUp }

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

// Model untuk Transaksi Firebase
class BillingTransaction {
  final int tableId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationInSeconds;
  final double totalCost;

  BillingTransaction({
    required this.tableId,
    required this.startTime,
    required this.endTime,
    required this.durationInSeconds,
    required this.totalCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'tableId': tableId,
      'startTime': startTime,
      'endTime': endTime,
      'durationInSeconds': durationInSeconds,
      'totalCost': totalCost,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// Fungsi main untuk inisialisasi Firebase
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Putra Jaya Billiard',
      debugShowCheckedModeBanner: false,
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

  // State untuk Kasir & Harga
  final Map<int, DateTime> _activeSessions = {};
  double _ratePerHour = 0.0;
  double _ratePerMinute = 0.0;

  @override
  void initState() {
    super.initState();
    _initRelayStates();
    _initPorts();
    _startLogicTimer();
    _loadRates();
  }

  @override
  void dispose() {
    _disconnectSerialPort();
    _logicTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ratePerHour = prefs.getDouble('ratePerHour') ?? 50000.0;
      _ratePerMinute = prefs.getDouble('ratePerMinute') ?? 0;
    });
    _addLog('Harga dimuat: Rp$_ratePerHour/jam, Rp$_ratePerMinute/menit');
  }

  void _initRelayStates() {
    for (int i = 1; i <= NUM_RELAYS; i++) {
      _relayStates[i] = RelayData(id: i);
    }
  }

  void _startLogicTimer() {
    _logicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final currentTime = DateTime.now();
      final Set<int> newlyFinishedTimerIds = {};
      bool uiNeedsUpdate = false;

      _relayStates.forEach((id, relay) {
        if (relay.status == RelayStatus.Timer && relay.timerEndTime != null) {
          uiNeedsUpdate = true;
          final remaining = relay.timerEndTime!
              .difference(currentTime)
              .inSeconds;

          if (remaining <= 0) {
            relay.remainingTimeSeconds = 0;
            relay.status = RelayStatus.TimeUp;
            relay.timerEndTime = null;
            newlyFinishedTimerIds.add(id);
          } else {
            relay.remainingTimeSeconds = remaining;
            if (remaining <= 300 && !relay.fiveMinuteWarningSent) {
              _addLog('Peringatan 5 menit Meja $id. Mengirim sinyal kedip.');
              relay.fiveMinuteWarningSent = true;
              _sendCommand(id, "BLINK");
            }
          }
        }
      });

      if (newlyFinishedTimerIds.isNotEmpty) {
        for (final id in newlyFinishedTimerIds) {
          _addLog('Waktu Meja $id HABIS. Menunggu pembayaran.');
          _sendCommand(id, "0");
        }
      }

      if (uiNeedsUpdate) {
        setState(() {});
      }
    });
  }

  void _startBillingSession(int mejaId) {
    if (_activeSessions.containsKey(mejaId)) {
      _addLog('Info: Meja $mejaId sudah memiliki sesi aktif.');
      return;
    }
    setState(() {
      _activeSessions[mejaId] = DateTime.now();
    });
    _addLog('Sesi billing Meja $mejaId dimulai.');
  }

  Future<void> _finalizeAndSaveBill(int mejaId) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) {
      _addLog(
        'Peringatan: Sesi Meja $mejaId tidak ditemukan untuk difinalisasi.',
      );
      _setRelayStateToOff(mejaId);
      return;
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final cost = (hours * _ratePerHour) + (minutes * _ratePerMinute);

    _addLog(
      'Sesi Meja $mejaId selesai. Durasi: ${duration.inMinutes} menit. Biaya: Rp${cost.toStringAsFixed(0)}',
    );

    final transaction = BillingTransaction(
      tableId: mejaId,
      startTime: startTime,
      endTime: endTime,
      durationInSeconds: duration.inSeconds,
      totalCost: cost,
    );

    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .add(transaction.toMap());
      _addLog('Transaksi Meja $mejaId berhasil disimpan ke Firebase.');
    } catch (e) {
      _addLog('Error menyimpan ke Firebase: $e');
    }

    setState(() {
      _activeSessions.remove(mejaId);
    });

    _setRelayStateToOff(mejaId);
  }

  Future<void> _showConfirmationDialog(int mejaId) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final finalCost = (hours * _ratePerHour) + (minutes * _ratePerMinute);

    String formatCurrency(double amount) {
      final format = intl.NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return format.format(amount);
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Pembayaran Meja $mejaId'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Durasi Main: ${_formatTime(duration.inSeconds)}'),
                const SizedBox(height: 12),
                Text(
                  'Total Tagihan: ${formatCurrency(finalCost)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Konfirmasi & Bayar'),
              onPressed: () {
                Navigator.of(context).pop();
                _finalizeAndSaveBill(mejaId);
              },
            ),
          ],
        );
      },
    );
  }

  void _setRelayStateToOff(int mejaId) {
    _addLog('Meja $mejaId: Relay dimatikan.');
    setState(() {
      _relayStates[mejaId]!.status = RelayStatus.Off;
      _relayStates[mejaId]!.timerEndTime = null;
      _relayStates[mejaId]!.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "0");
  }

  void _cancelSessionAndTurnOff(int mejaId) {
    if (_activeSessions.containsKey(mejaId)) {
      _addLog('Sesi Meja $mejaId DIBATALKAN tanpa transaksi.');
      setState(() {
        _activeSessions.remove(mejaId);
      });
    }
    _setRelayStateToOff(mejaId);
  }

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
        ..baudRate =
            9600 // Pastikan ini sesuai dengan hardware Anda
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

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      final timestamp = intl.DateFormat('HH:mm:ss').format(DateTime.now());
      _logMessages = '$timestamp - $message\n$_logMessages';
      if (_logMessages.length > 3000) {
        _logMessages = _logMessages.substring(0, 3000);
      }
    });
    if (_logScrollController.hasClients) {
      _logScrollController.jumpTo(0);
    }
  }

  void _turnOnRelay(int mejaId) {
    if (_activeSessions.containsKey(mejaId)) return; // Cegah mulai ganda
    _addLog('Meja $mejaId: Mode Personal (ON)');
    setState(() {
      _relayStates[mejaId]!.status = RelayStatus.On;
      _relayStates[mejaId]!.timerEndTime = null;
      _relayStates[mejaId]!.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "1");
    _startBillingSession(mejaId);
  }

  void _startTimer(int mejaId, int totalSeconds) {
    if (_activeSessions.containsKey(mejaId)) return; // Cegah mulai ganda
    _addLog('Meja $mejaId: Timer dimulai (${_formatTime(totalSeconds)})');
    setState(() {
      final relay = _relayStates[mejaId]!;
      relay.status = RelayStatus.Timer;
      relay.timerEndTime = DateTime.now().add(Duration(seconds: totalSeconds));
      relay.remainingTimeSeconds = totalSeconds;
      relay.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "1");
    _startBillingSession(mejaId);
  }

  Future<void> _showSetTimerDialog(int mejaId) async {
    if (_activeSessions.containsKey(mejaId)) {
      _addLog("Error: Meja $mejaId sudah aktif.");
      return;
    }
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Putra Jaya Billiard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Transaksi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Laporan Pendapatan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan Harga',
            onPressed: () async {
              final settingsChanged = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
              if (settingsChanged == true) {
                _loadRates();
              }
            },
          ),
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
      body: SlidingUpPanel(
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 1.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: NUM_RELAYS,
            itemBuilder: (context, index) {
              final mejaId = index + 1;
              final relay = _relayStates[mejaId]!;
              final bool isSessionActive = _activeSessions.containsKey(mejaId);
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
                case RelayStatus.TimeUp:
                  statusText = 'WAKTU HABIS';
                  cardColor = Colors.red.shade900;
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
                            tooltip: 'Matikan (Batalkan Sesi)',
                            onPressed: () => _cancelSessionAndTurnOff(mejaId),
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
                      if (isSessionActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Selesaikan & Bayar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                              onPressed: () => _showConfirmationDialog(mejaId),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        panel: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Log Komunikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                    padding: const EdgeInsets.only(
                      top: 4.0,
                      left: 8.0,
                      right: 8.0,
                    ),
                    child: Text(
                      _logMessages,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        minHeight: screenHeight * 0.1,
        maxHeight: screenHeight * 0.7,
        backdropEnabled: true,
        color: const Color(0xFF2a2a2a),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
    );
  }
}
