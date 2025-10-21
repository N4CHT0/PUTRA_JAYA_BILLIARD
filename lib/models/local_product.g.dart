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
      isActive: fields[3] as bool,
      variants: (fields[4] as List).cast<ProductVariant>(),
    );
  }

  @override
  void write(BinaryWriter writer, LocalProduct obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.variants);
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
