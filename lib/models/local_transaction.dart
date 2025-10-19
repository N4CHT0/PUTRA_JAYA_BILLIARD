// lib/models/local_transaction.dart

import 'package:hive/hive.dart';

part 'local_transaction.g.dart';

@HiveType(typeId: 4)
class LocalTransaction extends HiveObject {
  @HiveField(0)
  String flow;

  @HiveField(1)
  String type;

  @HiveField(2)
  double totalAmount;

  @HiveField(3)
  DateTime createdAt;

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

  // ✅ UBAH DI SINI
  @HiveField(17)
  String? paymentMethod;

  LocalTransaction({
    required this.flow,
    required this.type,
    required this.totalAmount,
    required this.createdAt,
    required this.cashierId,
    required this.cashierName,
    // ✅ UBAH DI SINI
    this.paymentMethod = 'Cash',
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

  Map<String, dynamic> toJson() => {
        'flow': flow,
        'type': type,
        'totalAmount': totalAmount,
        'createdAt': createdAt.toIso8601String(),
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
        'paymentMethod': paymentMethod,
      };

  factory LocalTransaction.fromJson(Map<String, dynamic> json) =>
      LocalTransaction(
        flow: json['flow'],
        type: json['type'],
        totalAmount: json['totalAmount'],
        createdAt: DateTime.parse(json['createdAt']),
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
        paymentMethod: json['paymentMethod'] ?? 'Cash',
      );
}
