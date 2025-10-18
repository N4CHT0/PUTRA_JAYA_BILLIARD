// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_stock_mutation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalStockMutationAdapter extends TypeAdapter<LocalStockMutation> {
  @override
  final int typeId = 5;

  @override
  LocalStockMutation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalStockMutation(
      productId: fields[0] as String,
      productName: fields[1] as String,
      type: fields[2] as String,
      quantityChange: fields[3] as int,
      stockBefore: fields[4] as int,
      notes: fields[5] as String,
      date: fields[6] as DateTime,
      userId: fields[7] as String,
      userName: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LocalStockMutation obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.quantityChange)
      ..writeByte(4)
      ..write(obj.stockBefore)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.userName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalStockMutationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
