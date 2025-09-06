import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nama;
  final String email;
  final String role;
  final String organisasi;
  final String kodeOrganisasi;

  UserModel({
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
    required this.organisasi,
    required this.kodeOrganisasi,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nama: data['nama'] ?? 'Tanpa Nama',
      email: data['email'] ?? 'Email tidak ada',
      role: data['role'] ?? 'pegawai',
      organisasi: data['organisasi'] ?? 'N/A',
      kodeOrganisasi: data['kodeOrganisasi'] ?? 'N/A',
    );
  }
}
