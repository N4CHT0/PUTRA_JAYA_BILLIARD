// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalTransactionAdapter extends TypeAdapter<LocalTransaction> {
  @override
  final int typeId = 4;

  @override
  LocalTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalTransaction(
      flow: fields[0] as String,
      type: fields[1] as String,
      totalAmount: fields[2] as double,
      createdAt: fields[3] as DateTime,
      cashierId: fields[4] as String,
      cashierName: fields[5] as String,
      paymentMethod: fields[17] as String?,
      items: (fields[6] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      supplierId: fields[7] as String?,
      supplierName: fields[8] as String?,
      tableId: fields[9] as int?,
      startTime: fields[10] as DateTime?,
      endTime: fields[11] as DateTime?,
      durationInSeconds: fields[12] as int?,
      subtotal: fields[13] as double?,
      discount: fields[14] as double?,
      memberId: fields[15] as String?,
      memberName: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalTransaction obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.flow)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.totalAmount)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.cashierId)
      ..writeByte(5)
      ..write(obj.cashierName)
      ..writeByte(6)
      ..write(obj.items)
      ..writeByte(7)
      ..write(obj.supplierId)
      ..writeByte(8)
      ..write(obj.supplierName)
      ..writeByte(9)
      ..write(obj.tableId)
      ..writeByte(10)
      ..write(obj.startTime)
      ..writeByte(11)
      ..write(obj.endTime)
      ..writeByte(12)
      ..write(obj.durationInSeconds)
      ..writeByte(13)
      ..write(obj.subtotal)
      ..writeByte(14)
      ..write(obj.discount)
      ..writeByte(15)
      ..write(obj.memberId)
      ..writeByte(16)
      ..write(obj.memberName)
      ..writeByte(17)
      ..write(obj.paymentMethod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
