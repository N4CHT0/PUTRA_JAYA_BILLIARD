// lib/pages/dashboard/dashboard_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/models/billing_transaction.dart';
import 'package:putra_jaya_billiard/models/relay_data.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

const int numRelays = 32;

class DashboardPage extends StatefulWidget {
  final UserModel user;

  const DashboardPage({
    super.key,
    required this.user,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ArduinoService _arduinoService = ArduinoService();
  final FirebaseService _firebaseService = FirebaseService();
  List<String> _availablePorts = [];
  final Map<int, RelayData> _relayStates = {};
  final Map<int, DateTime> _activeSessions = {};
  Timer? _logicTimer;
  String _logMessages = '';
  double _ratePerHour = 50000.0;
  double _ratePerMinute = 0.0;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initRelayStates();
    _initPorts();
    _startLogicTimer();
    _loadRates();
    _arduinoService.onDataReceived = (data) => _addLog('Arduino: $data');
  }

  @override
  void dispose() {
    _arduinoService.dispose();
    _logicTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _finalizeAndSaveBill(int mejaId) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) {
      _addLog('Peringatan: Sesi Meja $mejaId tidak ditemukan.');
      _setRelayStateToOff(mejaId);
      return;
    }
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    final cost = _calculateCost(duration);

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
      // --- PENYESUAIAN DI SINI ---
      // Memanggil fungsi baru 'saveBillingTransaction' dan menyertakan data 'widget.user'
      await _firebaseService.saveBillingTransaction(transaction, widget.user);
      _addLog('Transaksi Meja $mejaId berhasil disimpan ke Firebase.');
    } catch (e) {
      _addLog('Error menyimpan ke Firebase: $e');
    }

    if (!mounted) return;
    setState(() {
      _activeSessions.remove(mejaId);
    });
    _setRelayStateToOff(mejaId);
  }

  void _initRelayStates() {
    for (int i = 1; i <= numRelays; i++) {
      _relayStates[i] = RelayData(id: i);
    }
  }

  Future<void> _loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ratePerHour = prefs.getDouble('ratePerHour') ?? 50000.0;
      _ratePerMinute = prefs.getDouble('ratePerMinute') ?? 0;
    });
    _addLog('Harga dimuat: Rp$_ratePerHour/jam, Rp$_ratePerMinute/menit');
  }

  void _startLogicTimer() {
    _logicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final currentTime = DateTime.now();
      final Set<int> newlyFinishedTimerIds = {};
      bool uiNeedsUpdate = false;
      _relayStates.forEach((id, relay) {
        if (relay.status == RelayStatus.timer && relay.timerEndTime != null) {
          uiNeedsUpdate = true;
          final remaining =
              relay.timerEndTime!.difference(currentTime).inSeconds;

          if (remaining <= 0) {
            relay.remainingTimeSeconds = 0;
            relay.status = RelayStatus.timeUp;
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

  void _turnOnRelay(int mejaId) {
    if (_activeSessions.containsKey(mejaId)) return;
    _addLog('Meja $mejaId: Mode Personal (ON)');
    setState(() {
      _relayStates[mejaId]!.status = RelayStatus.on;
      _relayStates[mejaId]!.timerEndTime = null;
      _relayStates[mejaId]!.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "1");
    _startBillingSession(mejaId);
  }

  void _startTimer(int mejaId, int totalSeconds) {
    if (_activeSessions.containsKey(mejaId)) return;
    _addLog('Meja $mejaId: Timer dimulai (${_formatDuration(totalSeconds)})');
    setState(() {
      final relay = _relayStates[mejaId]!;
      relay.status = RelayStatus.timer;
      relay.timerEndTime = DateTime.now().add(Duration(seconds: totalSeconds));
      relay.remainingTimeSeconds = totalSeconds;
      relay.fiveMinuteWarningSent = false;
    });
    _sendCommand(mejaId, "1");
    _startBillingSession(mejaId);
  }

  void _setRelayStateToOff(int mejaId) {
    _addLog('Meja $mejaId: Relay dimatikan.');
    setState(() {
      _relayStates[mejaId]!.status = RelayStatus.off;
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
    setState(() => _availablePorts = _arduinoService.getAvailablePorts());
  }

  Future<void> _connectSerialPort(String portName) async {
    await _arduinoService.connect(
      portName,
      onConnected: () {
        if (!mounted) return;
        setState(() {});
        _addLog('Berhasil terhubung ke $portName');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {});
        _addLog(error);
      },
    );
  }

  Future<void> _disconnectSerialPort() async {
    await _arduinoService.disconnect();
    if (!mounted) return;
    setState(() {});
    _addLog('Koneksi terputus.');
  }

  Future<void> _sendCommand(int mejaId, String action) async {
    final success = await _arduinoService.sendCommand(mejaId, action);
    if (!success) {
      _addLog('Error: Gagal mengirim perintah ke Arduino (tidak terkoneksi).');
    }
  }

  Future<void> _showConfirmationDialog(int mejaId) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    final finalCost = _calculateCost(duration);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Konfirmasi Pembayaran Meja $mejaId'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Durasi Main: ${_formatDuration(duration.inSeconds)}'),
                const SizedBox(height: 12),
                Text(
                  'Total Tagihan: ${_formatCurrency(finalCost)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
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
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Menit',
                  hintText: 'Contoh: 30',
                  border: OutlineInputBorder(),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent),
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

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatCurrency(double amount) {
    final format = intl.NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  double _calculateCost(Duration duration) {
    return (duration.inHours * _ratePerHour) +
        (duration.inMinutes.remainder(60) * _ratePerMinute);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double panelMinHeight = screenHeight * 0.1;

    return SlidingUpPanel(
      panel: _buildLogPanel(),
      collapsed: _buildCollapsedPanel(),
      minHeight: panelMinHeight,
      maxHeight: screenHeight * 0.6,
      color: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildConnectionStatusPanel(),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, panelMinHeight + 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380,
                  childAspectRatio: 1.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: numRelays,
                itemBuilder: (context, index) {
                  final mejaId = index + 1;
                  final relay = _relayStates[mejaId]!;
                  final bool isSessionActive =
                      _activeSessions.containsKey(mejaId);
                  return _buildGlassCard(mejaId, relay, isSessionActive);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusPanel() {
    final isConnected = _arduinoService.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(51, 0, 0, 0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error,
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected
                    ? 'Terhubung: ${_arduinoService.connectedPortName}'
                    : 'Tidak Terhubung',
              ),
            ],
          ),
          if (!isConnected)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _initPorts,
                  tooltip: 'Refresh Port List',
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: null,
                    hint: const Text('Pilih Port'),
                    items: _availablePorts
                        .map<DropdownMenuItem<String>>((String port) {
                      return DropdownMenuItem<String>(
                        value: port,
                        child: Text(port),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _connectSerialPort(newValue);
                      }
                    },
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: _disconnectSerialPort,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Putuskan'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  ({String statusText, List<Color> gradientColors, Color statusColor})
      _getCardStyle(RelayData relay) {
    switch (relay.status) {
      case RelayStatus.on:
        return (
          statusText: 'ON (Personal)',
          gradientColors: [const Color(0xff22c1c3), const Color(0xfffdbb2d)],
          statusColor: Colors.greenAccent
        );
      case RelayStatus.timer:
        final bool isWarning =
            relay.remainingTimeSeconds <= 300 && relay.remainingTimeSeconds > 0;
        return (
          statusText: 'TIMER: ${_formatDuration(relay.remainingTimeSeconds)}',
          gradientColors: isWarning
              ? [const Color(0xffd66d75), const Color(0xffe29587)]
              : [const Color(0xfff3904f), const Color(0xff3b4371)],
          statusColor: isWarning ? Colors.orangeAccent : Colors.cyanAccent
        );
      case RelayStatus.timeUp:
        return (
          statusText: 'WAKTU HABIS',
          gradientColors: [const Color(0xffcb2d3e), const Color(0xffef473a)],
          statusColor: Colors.redAccent
        );
      case RelayStatus.off:
        return (
          statusText: 'OFF',
          gradientColors: [
            const Color.fromARGB(26, 255, 255, 255),
            const Color.fromARGB(13, 255, 255, 255),
          ],
          statusColor: Colors.grey.shade600
        );
    }
  }

  Widget _buildGlassCard(int mejaId, RelayData relay, bool isSessionActive) {
    final style = _getCardStyle(relay);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: style.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color.fromARGB(51, 255, 255, 255)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meja $mejaId',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  style.statusText,
                  style: TextStyle(fontSize: 16, color: style.statusColor),
                ),
                const Spacer(),
                if (isSessionActive)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Selesaikan & Bayar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(204, 0, 150, 136),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showConfirmationDialog(mejaId),
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: TextButton(
                          child: const Text('Batalkan Sesi',
                              style: TextStyle(color: Colors.white70)),
                          onPressed: () => _cancelSessionAndTurnOff(mejaId),
                        ),
                      )
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildControlButton(
                        Icons.play_arrow,
                        'Nyalakan (Personal)',
                        () => _turnOnRelay(mejaId),
                      ),
                      const SizedBox(width: 12),
                      _buildControlButton(
                        Icons.timer,
                        'Set Timer',
                        () => _showSetTimerDialog(mejaId),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color.fromARGB(64, 0, 0, 0),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildLogPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24.0),
        topRight: Radius.circular(24.0),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(77, 0, 0, 0),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Log Komunikasi',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () => setState(() => _logMessages = ''),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  controller: _logScrollController,
                  reverse: true,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _logMessages,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24.0),
        topRight: Radius.circular(24.0),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(77, 0, 0, 0),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const Text(
                  "Log Komunikasi",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
