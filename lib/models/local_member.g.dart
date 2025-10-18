// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_member.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalMemberAdapter extends TypeAdapter<LocalMember> {
  @override
  final int typeId = 2;

  @override
  LocalMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalMember(
      id: fields[0] as String?,
      name: fields[1] as String,
      address: fields[2] as String,
      phone: fields[3] as String,
      joinDate: fields[4] as DateTime,
      isActive: fields[5] as bool,
      discountPercentage: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LocalMember obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.joinDate)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.discountPercentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
