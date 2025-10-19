import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:putra_jaya_billiard/models/cart_item_model.dart';
import 'package:putra_jaya_billiard/models/local_member.dart';
import 'package:putra_jaya_billiard/models/local_payment_method.dart';
import 'package:putra_jaya_billiard/models/local_product.dart';
import 'package:putra_jaya_billiard/models/local_transaction.dart';
import 'package:putra_jaya_billiard/models/relay_data.dart';
import 'package:putra_jaya_billiard/models/user_model.dart';
import 'package:putra_jaya_billiard/pages/connection/connection_page.dart';
import 'package:putra_jaya_billiard/services/arduino_service.dart';
import 'package:putra_jaya_billiard/services/billing_services.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';
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
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  final BillingService _billingService = BillingService();
  final Map<int, RelayData> _relayStates = {};
  final Map<int, DateTime> _activeSessions = {};
  Timer? _logicTimer;
  String _logMessages = '';
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

  // Method publik untuk menerima item dari PosPage
  void addToCartToTable(int tableId, List<CartItem> items) {
    setState(() {
      final relay = _relayStates[tableId];
      if (relay != null && _activeSessions.containsKey(tableId)) {
        // Buat list baru agar Flutter mendeteksi perubahan
        relay.posItems = List<CartItem>.from(relay.posItems)..addAll(items);
        _addLog('${items.length} item F&B ditambahkan ke Meja $tableId.');
      } else {
        _addLog(
            'Error: Tidak dapat menambahkan item ke Meja $tableId karena sesi tidak aktif.');
      }
    });
  }

  // Method publik untuk mendapatkan ID meja yang aktif
  List<int> getActiveTableIds() {
    return _activeSessions.keys.toList()..sort();
  }

  void loadRatesAfterSave() {
    _addLog('PENGATURAN DIPERBARUI. Memuat ulang tarif...');
    _loadRates();
  }

  void _initRelayStates() {
    for (int i = 1; i <= numRelays; i++) {
      _relayStates[i] = RelayData(id: i, posItems: []);
    }
  }

  Future<void> _loadRates() async {
    await _billingService.loadRates();
    if (!mounted) return;
    setState(() {});
    _addLog('Tarif harga berhasil dimuat.');
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

  Future<void> _finalizeAndSaveBill(
    int mejaId, {
    LocalMember? member,
    required double subtotal,
    required double discount,
    required double finalTotal,
    required String paymentMethod,
  }) async {
    final startTime = _activeSessions[mejaId];
    if (startTime == null) return;

    final endTime = DateTime.now();
    final relay = _relayStates[mejaId]!;
    final int durationToBillSeconds =
        relay.setTimerSeconds ?? endTime.difference(startTime).inSeconds;

    final posItemsToSave = List<CartItem>.from(relay.posItems);

    _setRelayStateToOff(mejaId);
    if (mounted) {
      setState(() => _activeSessions.remove(mejaId));
    }

    _addLog(
        'Sesi Meja $mejaId selesai. Total: ${_formatCurrency(finalTotal)} dibayar dengan $paymentMethod');

    final localTransaction = LocalTransaction(
      flow: 'income',
      type: 'billiard', // Tipe utama tetap billiard
      totalAmount: finalTotal,
      createdAt: startTime,
      cashierId: widget.user.uid,
      cashierName: widget.user.nama,
      tableId: mejaId,
      startTime: startTime,
      endTime: endTime,
      durationInSeconds: durationToBillSeconds,
      subtotal: subtotal,
      discount: discount,
      memberId: member?.key.toString(),
      memberName: member?.name,
      paymentMethod: paymentMethod,
      items: posItemsToSave.map((item) {
        final product = item.product as LocalProduct;
        return {
          'productId': product.key.toString(),
          'productName': product.name,
          'quantity': item.quantity,
          'price': product.sellingPrice,
        };
      }).toList(),
    );

    try {
      await _localDbService.addTransaction(localTransaction);
      _addLog('Transaksi Meja $mejaId berhasil disimpan (Lokal).');
    } catch (e) {
      _addLog('ERROR: Gagal menyimpan transaksi Meja $mejaId (Lokal): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan transaksi ke database lokal.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendCommand(int mejaId, String action) async {
    if (!mounted) return;
    final success = await widget.arduinoService.sendCommand(mejaId, action);
    if (!success && mounted) {
      _addLog('Error: Gagal mengirim perintah ke Arduino (tidak terkoneksi).');
    }
  }

  void _turnOnRelay(int mejaId) {
    if (_activeSessions.containsKey(mejaId)) return;
    _addLog('Meja $mejaId: Mode Personal (ON)');
    setState(() {
      final relay = _relayStates[mejaId]!;
      relay.status = RelayStatus.on;
      relay.timerEndTime = null;
      relay.fiveMinuteWarningSent = false;
      relay.setTimerSeconds = null;
      relay.posItems = [];
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
      relay.setTimerSeconds = totalSeconds;
      relay.posItems = [];
    });
    _sendCommand(mejaId, "1");
    _startBillingSession(mejaId);
  }

  void _setRelayStateToOff(int mejaId) {
    _addLog('Meja $mejaId: Relay dimatikan.');
    setState(() {
      final relay = _relayStates[mejaId]!;
      relay.status = RelayStatus.off;
      relay.timerEndTime = null;
      relay.fiveMinuteWarningSent = false;
      relay.setTimerSeconds = null;
      relay.posItems = [];
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

    LocalMember? selectedMemberInDialog;
    String selectedPaymentMethod = 'Cash';

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateInDialog) {
            final relay = _relayStates[mejaId]!;
            final Duration billingDuration = relay.setTimerSeconds != null
                ? Duration(seconds: relay.setTimerSeconds!)
                : DateTime.now().difference(startTime);

            final billiardSubtotal = _billingService
                .calculateBilliardFee(billingDuration, date: startTime);
            final double posSubtotal = relay.posItems.fold(
                0,
                (sum, item) =>
                    sum +
                    ((item.product as LocalProduct).sellingPrice *
                        item.quantity));
            final grandSubtotal = billiardSubtotal + posSubtotal;
            final discountPercentage =
                selectedMemberInDialog?.discountPercentage ?? 0;
            final discountAmount = grandSubtotal * (discountPercentage / 100);
            final finalCost = grandSubtotal - discountAmount;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Konfirmasi Pembayaran Meja $mejaId'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                        'Waktu Main Aktual: ${_formatDuration(DateTime.now().difference(startTime).inSeconds)}'),
                    if (relay.setTimerSeconds != null)
                      Text(
                          'Durasi Paket Dikenakan: ${_formatDuration(billingDuration.inSeconds)}'),
                    const Divider(height: 20, color: Colors.white24),
                    _buildPriceRow('Subtotal Billiard:', billiardSubtotal),
                    if (posSubtotal > 0)
                      _buildPriceRow('Subtotal F&B:', posSubtotal),
                    if (discountAmount > 0)
                      _buildPriceRow(
                          'Diskon ($discountPercentage%):', -discountAmount,
                          color: Colors.amberAccent),
                    const Divider(height: 12, color: Colors.white24),
                    _buildPriceRow('Total Tagihan:', finalCost, isTotal: true),
                    if (relay.posItems.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Detail Pesanan F&B:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...relay.posItems.map((item) {
                        final product = item.product as LocalProduct;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item.quantity}x ${product.name}'),
                          trailing: Text(_formatCurrency(
                              product.sellingPrice * item.quantity)),
                        );
                      }).toList(),
                    ],
                    const Divider(height: 24, color: Colors.white24),
                    const Text('Metode Pembayaran:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ValueListenableBuilder<Box<LocalPaymentMethod>>(
                      valueListenable:
                          _localDbService.getPaymentMethodsListenable(),
                      builder: (context, box, _) {
                        final paymentMethods = box.values
                            .where((p) => p.isActive)
                            .map((p) => p.name)
                            .toList();
                        final allOptions = {'Cash', ...paymentMethods}.toList();

                        return DropdownButton<String>(
                          value: selectedPaymentMethod,
                          isExpanded: true,
                          underline:
                              Container(height: 1, color: Colors.white24),
                          dropdownColor: const Color(0xFF2c2c2c),
                          items: allOptions.map((String value) {
                            return DropdownMenuItem<String>(
                                value: value, child: Text(value));
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setStateInDialog(
                                  () => selectedPaymentMethod = newValue);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Pelanggan:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ValueListenableBuilder<Box<LocalMember>>(
                      valueListenable: _localDbService.getMemberListenable(),
                      builder: (context, box, _) {
                        final members = box.values.toList().cast<LocalMember>();
                        List<DropdownMenuItem<LocalMember?>> items = [
                          const DropdownMenuItem<LocalMember?>(
                            value: null,
                            child: Text('Pelanggan Umum'),
                          ),
                          ...members.where((m) => m.isActive).map((member) {
                            return DropdownMenuItem<LocalMember?>(
                              value: member,
                              child: Text(member.name),
                            );
                          }).toList(),
                        ];
                        final currentSelectionExists = members
                            .any((m) => m.key == selectedMemberInDialog?.key);
                        if (!currentSelectionExists) {
                          selectedMemberInDialog = null;
                        }
                        return DropdownButton<LocalMember?>(
                          value: selectedMemberInDialog,
                          hint: const Text('Pilih Member (Opsional)'),
                          isExpanded: true,
                          underline:
                              Container(height: 1, color: Colors.white24),
                          dropdownColor: const Color(0xFF2c2c2c),
                          items: items,
                          onChanged: (LocalMember? newValue) {
                            setStateInDialog(
                                () => selectedMemberInDialog = newValue);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                    child: const Text('Batal'),
                    onPressed: () => Navigator.of(dialogContext).pop()),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Konfirmasi & Bayar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _finalizeAndSaveBill(
                      mejaId,
                      member: selectedMemberInDialog,
                      subtotal: grandSubtotal,
                      discount: discountAmount,
                      finalTotal: finalCost,
                      paymentMethod: selectedPaymentMethod,
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

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
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
              onPressed: () => Navigator.of(dialogContext).pop(),
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
                  Navigator.of(dialogContext).pop();
                } else {
                  if (mounted) _addLog('Input durasi tidak valid.');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(0);
      }
    });
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
        title: const Text('Kontrol Meja Billiard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Tooltip(
            key: const ValueKey('connection_tooltip'),
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
