// lib/pages/dashboard/dashboard_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/models/billing_transaction.dart';
import 'package:putra_jaya_billiard/models/member_model.dart';
import 'package:putra_jaya_billiard/models/relay_data.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/connection/connection_page.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'widgets/billiard_table_card.dart';
import 'widgets/log_panel.dart';

const int numRelays = 32;

class DashboardPage extends StatefulWidget {
  final UserModel user;
  final ArduinoService arduinoService;

  const DashboardPage({
    super.key,
    required this.user,
    required this.arduinoService,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseService _firebaseService = FirebaseService();
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
    _startLogicTimer();
    _loadRates();
    widget.arduinoService.onDataReceived = (data) => _addLog('Arduino: $data');
    widget.arduinoService.onConnectionChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.arduinoService.onConnectionChanged = null;
    _logicTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
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

  Future<void> _finalizeAndSaveBill(int mejaId,
      {Member? member,
      required double subtotal,
      required double discount,
      required double finalTotal}) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) return;

    _setRelayStateToOff(mejaId);
    if (mounted) {
      setState(() => _activeSessions.remove(mejaId));
    }

    _addLog('Sesi Meja $mejaId selesai. Total: ${_formatCurrency(finalTotal)}');

    final transaction = BillingTransaction(
      tableId: mejaId,
      startTime: startTime,
      endTime: DateTime.now(),
      durationInSeconds: DateTime.now().difference(startTime).inSeconds,
      totalCost: subtotal,
    );

    try {
      await _firebaseService.saveBillingTransaction(
        transaction,
        widget.user,
        member: member,
        subtotal: subtotal,
        discount: discount,
        finalTotal: finalTotal,
      );
      _addLog('Transaksi Meja $mejaId berhasil disimpan ke Firebase.');
    } catch (e) {
      _addLog('ERROR: Gagal menyimpan transaksi Meja $mejaId ke Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan transaksi ke server.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendCommand(int mejaId, String action) async {
    final success = await widget.arduinoService.sendCommand(mejaId, action);
    if (!success) {
      _addLog('Error: Gagal mengirim perintah ke Arduino (tidak terkoneksi).');
    }
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

  Future<void> _showConfirmationDialog(int mejaId) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) return;

    Member? selectedMemberInDialog;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            final duration = DateTime.now().difference(startTime);
            final subtotal = _calculateCost(duration);
            final discountPercentage =
                selectedMemberInDialog?.discountPercentage ?? 0;
            final discountAmount = subtotal * (discountPercentage / 100);
            final finalCost = subtotal - discountAmount;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Konfirmasi Pembayaran Meja $mejaId'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Durasi Main: ${_formatDuration(duration.inSeconds)}'),
                    const SizedBox(height: 12),
                    _buildPriceRow('Subtotal:', subtotal),
                    if (discountAmount > 0)
                      _buildPriceRow(
                          'Diskon ($discountPercentage%):', -discountAmount,
                          color: Colors.amberAccent),
                    const Divider(height: 12, color: Colors.white24),
                    _buildPriceRow('Total Tagihan:', finalCost, isTotal: true),
                    const Divider(height: 24, color: Colors.white24),
                    StreamBuilder<List<Member>>(
                      stream: _firebaseService.getMembersStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: Text("Memuat member..."));
                        }
                        final members = snapshot.data!;
                        List<DropdownMenuItem<Member?>> items = [
                          const DropdownMenuItem<Member?>(
                            value: null,
                            child: Text('Pelanggan Umum'),
                          ),
                          ...members.where((m) => m.isActive).map((member) {
                            return DropdownMenuItem<Member?>(
                              value: member,
                              child: Text(member.name),
                            );
                          }).toList(),
                        ];
                        return DropdownButton<Member?>(
                          value: selectedMemberInDialog,
                          hint: const Text('Pilih Member (Opsional)'),
                          isExpanded: true,
                          items: items,
                          onChanged: (Member? newValue) {
                            setStateInDialog(
                                () => selectedMemberInDialog = newValue);
                          },
                        );
                      },
                    )
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                    child: const Text('Batal'),
                    onPressed: () => Navigator.of(context).pop()),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Konfirmasi & Bayar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _finalizeAndSaveBill(
                      mejaId,
                      member: selectedMemberInDialog,
                      subtotal: subtotal,
                      discount: discountAmount,
                      finalTotal: finalCost,
                    );
                  },
                ),
              ],
            );
          },
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

  Widget _buildPriceRow(String label, double amount,
      {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14)),
          Text(_formatCurrency(amount),
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontWeight: FontWeight.bold,
                  color:
                      color ?? (isTotal ? Colors.cyanAccent : Colors.white))),
        ],
      ),
    );
  }

  void _navigateToConnectionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectionPage(
          arduinoService: widget.arduinoService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double panelMinHeight = screenHeight * 0.1;

    final logPanel = LogPanel(
      logMessages: _logMessages,
      logScrollController: _logScrollController,
      onClearLog: () => setState(() => _logMessages = ''),
    );

    final bool isConnected = widget.arduinoService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Putra Jaya Billiard - Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Tooltip(
            key: const ValueKey('connection_tooltip'), // <-- TAMBAHKAN INI
            message: isConnected
                ? 'Terhubung'
                : 'Tidak Terhubung - Klik untuk mengatur',
            child: IconButton(
              icon: Icon(
                Icons.usb,
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
              onPressed: _navigateToConnectionPage,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SlidingUpPanel(
        panel: logPanel.buildPanel(),
        collapsed: logPanel.buildCollapsed(),
        minHeight: panelMinHeight,
        maxHeight: screenHeight * 0.6,
        color: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
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
                    return BilliardTableCard(
                      tableId: mejaId,
                      relay: _relayStates[mejaId]!,
                      isSessionActive: _activeSessions.containsKey(mejaId),
                      onShowConfirmation: () => _showConfirmationDialog(mejaId),
                      onCancelSession: () => _cancelSessionAndTurnOff(mejaId),
                      onTurnOnRelay: () => _turnOnRelay(mejaId),
                      onShowSetTimer: () => _showSetTimerDialog(mejaId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
