// lib/models/supplier_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String? id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;

  Supplier({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'isActive': isActive,
    };
  }

  factory Supplier.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Supplier(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  // --- PERBAIKAN 1: Override operator '==' dan hashCode ---
  // Ini memberitahu Dart cara membandingkan dua objek Supplier berdasarkan ID-nya.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Supplier && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
