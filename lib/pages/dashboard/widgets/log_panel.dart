// lib/pages/dashboard/widgets/log_panel.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class LogPanel extends StatelessWidget {
  final String logMessages;
  final ScrollController logScrollController;
  final VoidCallback onClearLog;

  const LogPanel({
    super.key,
    required this.logMessages,
    required this.logScrollController,
    required this.onClearLog,
  });

  @override
  Widget build(BuildContext context) {
    // Ini adalah widget kosong karena panel akan dirender oleh SlidingUpPanel
    return const SizedBox.shrink();
  }

  Widget buildPanel() {
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
              _buildDragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Log Komunikasi',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: onClearLog,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  controller: logScrollController,
                  reverse: true,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      logMessages,
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

  Widget buildCollapsed() {
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
                _buildDragHandle(isCollapsed: true),
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

  Widget _buildDragHandle({bool isCollapsed = false}) {
    return Container(
      width: 40,
      height: 5,
      margin: EdgeInsets.only(
        top: 10.0,
        bottom: isCollapsed ? 8.0 : 10.0,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
