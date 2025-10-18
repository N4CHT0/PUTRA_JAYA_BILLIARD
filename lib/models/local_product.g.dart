// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalProductAdapter extends TypeAdapter<LocalProduct> {
  @override
  final int typeId = 1;

  @override
  LocalProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalProduct(
      id: fields[0] as String?,
      name: fields[1] as String,
      unit: fields[2] as String,
      purchasePrice: fields[3] as double,
      sellingPrice: fields[4] as double,
      stock: fields[5] as int,
      isActive: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalProduct obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.purchasePrice)
      ..writeByte(4)
      ..write(obj.sellingPrice)
      ..writeByte(5)
      ..write(obj.stock)
      ..writeByte(6)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
