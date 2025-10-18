import 'package:flutter/material.dart';
import 'package:putra_jaya_billiard/models/member_model.dart';
import 'package:putra_jaya_billiard/services/firebase_service.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
//INTERNAL_ERROR_DO_NOT_USE
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final FirebaseService _firebaseService = FirebaseService();

  void _showMemberDialog({Member? member}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: member?.name);
    final addressController = TextEditingController(text: member?.address);
    final phoneController = TextEditingController(text: member?.phone);
    // Controller untuk diskon
    final discountController = TextEditingController(
        text: member?.discountPercentage.toString() ?? '0');
    bool isActive = member?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(member == null ? 'Tambah Member Baru' : 'Edit Member',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Nama Member'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: addressController,
                          decoration:
                              const InputDecoration(labelText: 'Alamat'),
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      TextFormField(
                          controller: phoneController,
                          decoration:
                              const InputDecoration(labelText: 'No. Telepon'),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      // Field baru untuk input diskon
                      TextFormField(
                          controller: discountController,
                          decoration: const InputDecoration(
                              labelText: 'Diskon (%)', hintText: 'Contoh: 10'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Member Aktif'),
                        value: isActive,
                        onChanged: (bool? value) =>
                            setState(() => isActive = value ?? true),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.teal,
                      )
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newMember = Member(
                    id: member?.id,
                    name: nameController.text,
                    address: addressController.text,
                    phone: phoneController.text,
                    joinDate: member?.joinDate ?? DateTime.now(),
                    isActive: isActive,
                    // Ambil nilai diskon dari controller
                    discountPercentage:
                        double.tryParse(discountController.text) ?? 0,
                  );

                  if (member == null) {
                    _firebaseService.addMember(newMember);
                  } else {
                    _firebaseService.updateMember(newMember);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showMemberDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12)),
                child: StreamBuilder<List<Member>>(
                  stream: _firebaseService.getMembersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Belum ada member.'));
                    }
                    final members = snapshot.data!;
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.all(
                              Colors.white.withOpacity(0.1)),
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Nama')),
                            DataColumn(label: Text('Alamat')),
                            DataColumn(label: Text('Telepon')),
                            DataColumn(
                                label: Text('Diskon (%)'), numeric: true),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: members.map((member) {
                            return DataRow(
                              cells: [
                                DataCell(Text(member.id!.substring(0, 6))),
                                DataCell(Text(member.name)),
                                DataCell(Text(member.address)),
                                DataCell(Text(member.phone)),
                                // Tampilkan nilai diskon
                                DataCell(Text('${member.discountPercentage}%')),
                                DataCell(
                                  Icon(
                                    member.isActive
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: member.isActive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showMemberDialog(member: member),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _firebaseService
                                            .deleteMember(member.id!),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
