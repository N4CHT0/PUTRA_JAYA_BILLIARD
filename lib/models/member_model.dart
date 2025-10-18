// lib/models/member_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String? id;
  final String name;
  final String address;
  final String phone;
  final DateTime joinDate;
  final bool isActive;
  final double discountPercentage; // <-- FIELD BARU

  Member({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.joinDate,
    this.isActive = true,
    this.discountPercentage = 0, // <-- Default diskon 0%
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'joinDate': joinDate,
      'isActive': isActive,
      'discountPercentage': discountPercentage, // <-- Tambahkan ke map
    };
  }

  factory Member.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Member(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      joinDate: (data['joinDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      discountPercentage: (data['discountPercentage'] ?? 0)
          .toDouble(), // <-- Ambil dari Firestore
    );
  }

  // Override '==' dan 'hashCode' agar Dropdown berfungsi dengan benar
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
