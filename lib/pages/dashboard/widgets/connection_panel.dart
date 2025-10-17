// lib/pages/dashboard/widgets/connection_panel.dart

import 'package:flutter/material.dart';

class ConnectionPanel extends StatelessWidget {
  final bool isConnected;
  final String? connectedPortName;
  final List<String> availablePorts;
  final VoidCallback onRefreshPorts;
  final Function(String) onConnect;
  final VoidCallback onDisconnect;

  const ConnectionPanel({
    super.key,
    required this.isConnected,
    this.connectedPortName,
    required this.availablePorts,
    required this.onRefreshPorts,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
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
                    ? 'Terhubung: $connectedPortName'
                    : 'Tidak Terhubung',
              ),
            ],
          ),
          if (!isConnected)
            _buildConnectionControls()
          else
            TextButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Putuskan'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionControls() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefreshPorts,
          tooltip: 'Refresh Port List',
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: null,
            hint: const Text('Pilih Port'),
            items: availablePorts.map<DropdownMenuItem<String>>((String port) {
              return DropdownMenuItem<String>(
                value: port,
                child: Text(port),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                onConnect(newValue);
              }
            },
          ),
        ),
      ],
    );
  }
}
