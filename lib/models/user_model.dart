// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String role;
  final String organisasi;
  final String kodeOrganisasi;
  final String nama;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.organisasi,
    required this.kodeOrganisasi,
    required this.nama,
  });
}
