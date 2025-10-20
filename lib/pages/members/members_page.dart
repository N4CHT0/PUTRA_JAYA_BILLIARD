// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:putra_jaya_billiard/models/local_member.dart';
import 'package:putra_jaya_billiard/services/local_database_service.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final LocalDatabaseService _localDbService = LocalDatabaseService();

  void _showMemberDialog({LocalMember? member, dynamic memberKey}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: member?.name);
    final addressController = TextEditingController(text: member?.address);
    final phoneController = TextEditingController(text: member?.phone);
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
                      TextFormField(
                          controller: discountController,
                          decoration: const InputDecoration(
                              labelText: 'Diskon (%)', hintText: 'Contoh: 10'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null ||
                                v.isEmpty ||
                                double.tryParse(v) == null ||
                                double.parse(v) < 0 ||
                                double.parse(v) > 100) {
                              return 'Masukkan diskon 0-100';
                            }
                            return null;
                          }),
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newMember = LocalMember(
                    name: nameController.text,
                    address: addressController.text,
                    phone: phoneController.text,
                    joinDate: member?.joinDate ?? DateTime.now(),
                    isActive: isActive,
                    discountPercentage:
                        double.tryParse(discountController.text) ?? 0,
                  );

                  try {
                    if (member == null) {
                      await _localDbService.addMember(newMember);
                    } else {
                      await _localDbService.updateMember(memberKey, newMember);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Gagal menyimpan: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
      LocalMember member, dynamic memberKey) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Member?'),
        content: Text('Anda yakin ingin menghapus ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _localDbService.deleteMember(memberKey);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${member.name} berhasil dihapus.'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Manajemen Member'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showMemberDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Member'),
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
                child: ValueListenableBuilder<Box<LocalMember>>(
                  valueListenable: _localDbService.getMemberListenable(),
                  builder: (context, box, _) {
                    final members = box.values.toList().cast<LocalMember>();
                    members.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                    if (members.isEmpty) {
                      return const Center(child: Text('Belum ada member.'));
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.all(
                              Colors.white.withOpacity(0.1)),
                          columns: const [
                            DataColumn(label: Text('Nama')),
                            DataColumn(label: Text('Alamat')),
                            DataColumn(label: Text('Telepon')),
                            DataColumn(label: Text('Tgl. Bergabung')),
                            DataColumn(
                                label: Text('Diskon (%)'), numeric: true),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: members.map((member) {
                            final memberKey = member.key;
                            return DataRow(
                              cells: [
                                DataCell(Text(member.name)),
                                DataCell(Text(member.address)),
                                DataCell(Text(member.phone)),
                                DataCell(Text(DateFormat('dd/MM/yyyy')
                                    .format(member.joinDate))),
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
                                        onPressed: () => _showMemberDialog(
                                            member: member,
                                            memberKey: memberKey),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12)),
                                        child: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showDeleteConfirmation(
                                                member, memberKey),
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
