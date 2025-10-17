// lib/pages/dashboard/widgets/billiard_table_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/relay_data.dart';

class BilliardTableCard extends StatelessWidget {
  final int mejaId;
  final RelayData relay;
  final bool isSessionActive;
  final VoidCallback onTurnOn;
  final VoidCallback onSetTimer;
  final VoidCallback onFinalizeAndPay;
  final VoidCallback onCancelSession;

  const BilliardTableCard({
    super.key,
    required this.mejaId,
    required this.relay,
    required this.isSessionActive,
    required this.onTurnOn,
    required this.onSetTimer,
    required this.onFinalizeAndPay,
    required this.onCancelSession,
  });

  // Helper untuk memformat durasi
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // Helper untuk menentukan style kartu berdasarkan status relay
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

  @override
  Widget build(BuildContext context) {
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
                  _buildActiveSessionButtons()
                else
                  _buildInactiveSessionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Selesaikan & Bayar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(204, 0, 150, 136),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onFinalizeAndPay,
          ),
        ),
        SizedBox(
          height: 28,
          child: TextButton(
            child: const Text('Batalkan Sesi',
                style: TextStyle(color: Colors.white70)),
            onPressed: onCancelSession,
          ),
        )
      ],
    );
  }

  Widget _buildInactiveSessionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildControlButton(
          Icons.play_arrow,
          'Nyalakan (Personal)',
          onTurnOn,
        ),
        const SizedBox(width: 12),
        _buildControlButton(
          Icons.timer,
          'Set Timer',
          onSetTimer,
        ),
      ],
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
}
