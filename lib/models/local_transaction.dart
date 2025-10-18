// lib/models/local_transaction.dart

import 'package:hive/hive.dart';

part 'local_transaction.g.dart'; // Akan digenerate ulang

@HiveType(typeId: 4) // ID Tipe unik
class LocalTransaction extends HiveObject {
  @HiveField(0)
  String flow; // 'income' atau 'expense'

  @HiveField(1)
  String type; // 'billiard', 'pos', 'purchase'

  @HiveField(2)
  double totalAmount;

  @HiveField(3)
  DateTime createdAt; // Gunakan DateTime biasa

  @HiveField(4)
  String cashierId;

  @HiveField(5)
  String cashierName;

  @HiveField(6)
  List<Map<String, dynamic>>? items;

  @HiveField(7)
  String? supplierId;

  @HiveField(8)
  String? supplierName;

  @HiveField(9)
  int? tableId;

  @HiveField(10)
  DateTime? startTime;

  @HiveField(11)
  DateTime? endTime;

  @HiveField(12)
  int? durationInSeconds;

  @HiveField(13)
  double? subtotal;

  @HiveField(14)
  double? discount;

  @HiveField(15)
  String? memberId;

  @HiveField(16)
  String? memberName;

  // Constructor
  LocalTransaction({
    required this.flow,
    required this.type,
    required this.totalAmount,
    required this.createdAt,
    required this.cashierId,
    required this.cashierName,
    this.items,
    this.supplierId,
    this.supplierName,
    this.tableId,
    this.startTime,
    this.endTime,
    this.durationInSeconds,
    this.subtotal,
    this.discount,
    this.memberId,
    this.memberName,
  });

  // Method untuk mengubah objek menjadi Map (JSON) untuk backup
  Map<String, dynamic> toJson() => {
        'flow': flow,
        'type': type,
        'totalAmount': totalAmount,
        'createdAt': createdAt.toIso8601String(), // Simpan sbg string
        'cashierId': cashierId,
        'cashierName': cashierName,
        'items': items,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'tableId': tableId,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationInSeconds': durationInSeconds,
        'subtotal': subtotal,
        'discount': discount,
        'memberId': memberId,
        'memberName': memberName,
      };

  // Factory constructor untuk membuat objek dari Map (JSON) untuk restore/import
  factory LocalTransaction.fromJson(Map<String, dynamic> json) =>
      LocalTransaction(
        flow: json['flow'],
        type: json['type'],
        totalAmount: json['totalAmount'],
        createdAt: DateTime.parse(
            json['createdAt']), // Ubah string kembali ke DateTime
        cashierId: json['cashierId'],
        cashierName: json['cashierName'],
        items: (json['items'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        supplierId: json['supplierId'],
        supplierName: json['supplierName'],
        tableId: json['tableId'],
        startTime: json['startTime'] != null
            ? DateTime.parse(json['startTime'])
            : null,
        endTime:
            json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        durationInSeconds: json['durationInSeconds'],
        subtotal: json['subtotal'],
        discount: json['discount'],
        memberId: json['memberId'],
        memberName: json['memberName'],
      );
}
