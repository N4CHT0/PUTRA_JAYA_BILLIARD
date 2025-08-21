import 'package:cloud_firestore/cloud_firestore.dart';

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