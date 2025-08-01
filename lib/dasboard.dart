import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kontrol Relay Arduino',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          // Perbaikan: Menggunakan CardThemeData
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const ControlScreen(),
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // Controller untuk menyimpan alamat IP Arduino
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.1.177',
  );
  bool _isConnecting = false;

  // Fungsi untuk mengirim perintah ke Arduino
  Future<void> _sendCommand(String command) async {
    // Hapus fokus dari textfield untuk menutup keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isConnecting = true;
    });

    // Menampilkan snackbar bahwa perintah sedang dikirim
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengirim perintah: $command'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      // Membuat koneksi socket ke IP dan port Arduino
      final socket = await Socket.connect(
        _ipController.text,
        80,
        timeout: const Duration(seconds: 5),
      );
      // Mengirim data perintah
      socket.writeln(command);
      await socket.flush();
      socket.destroy();

      // Menampilkan snackbar sukses
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perintah berhasil dikirim!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Menampilkan snackbar jika terjadi error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal terhubung ke Arduino: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Relay Meja'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Input untuk alamat IP Arduino
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 16.0,
              ),
              child: TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Alamat IP Arduino',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.router),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            // Grid yang menampilkan 16 kartu meja
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 kartu per baris
                  childAspectRatio: 0.85, // Rasio aspek kartu
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 16, // Jumlah total meja
                itemBuilder: (context, index) {
                  return MejaCard(
                    tableNumber: index + 1,
                    onSendCommand: _sendCommand,
                    isEnabled: !_isConnecting,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget untuk setiap kartu meja
class MejaCard extends StatefulWidget {
  final int tableNumber;
  final Future<void> Function(String) onSendCommand;
  final bool isEnabled;

  const MejaCard({
    super.key,
    required this.tableNumber,
    required this.onSendCommand,
    required this.isEnabled,
  });

  @override
  State<MejaCard> createState() => _MejaCardState();
}

class _MejaCardState extends State<MejaCard> {
  final TextEditingController _timerController = TextEditingController();

  void _handleSetTimer() {
    final hours = int.tryParse(_timerController.text);
    if (hours != null && hours > 0) {
      // Konversi jam ke detik
      final seconds = hours * 3600;
      // Format perintah: "meja,PERINTAH,nilai"
      widget.onSendCommand('${widget.tableNumber},TIMER,$seconds');
      _timerController.clear();
      FocusScope.of(context).unfocus(); // Tutup keyboard
    } else {
      // Tampilkan error jika input tidak valid
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan jumlah jam yang valid.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Judul Kartu
            Text(
              'Meja ${widget.tableNumber}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),
            // Input Timer
            SizedBox(
              height: 40,
              child: TextField(
                controller: _timerController,
                enabled: widget.isEnabled,
                decoration: InputDecoration(
                  labelText: 'Jam',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            // Tombol Atur Timer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isEnabled ? _handleSetTimer : null,
                icon: const Icon(Icons.timer),
                label: const Text('Set Timer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            // Tombol Standby dan Off
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.isEnabled
                        ? () =>
                              widget.onSendCommand('${widget.tableNumber},ON,0')
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Standby'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.isEnabled
                        ? () => widget.onSendCommand(
                            '${widget.tableNumber},OFF,0',
                          )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Off'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
