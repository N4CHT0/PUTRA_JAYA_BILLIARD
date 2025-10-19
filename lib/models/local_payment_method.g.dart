// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_payment_method.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalPaymentMethodAdapter extends TypeAdapter<LocalPaymentMethod> {
  @override
  final int typeId = 6;

  @override
  LocalPaymentMethod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalPaymentMethod(
      name: fields[0] as String,
      isActive: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalPaymentMethod obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalPaymentMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
