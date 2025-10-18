// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_supplier.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalSupplierAdapter extends TypeAdapter<LocalSupplier> {
  @override
  final int typeId = 3;

  @override
  LocalSupplier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalSupplier(
      id: fields[0] as String?,
      name: fields[1] as String,
      address: fields[2] as String,
      phone: fields[3] as String,
      isActive: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalSupplier obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalSupplierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
