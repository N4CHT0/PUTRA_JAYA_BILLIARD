// lib/models/relay_data.dart
import 'package:putra_jaya_billiard/models/cart_item_model.dart'; // ✅ Import CartItem

enum RelayStatus { off, on, timer, timeUp }

class RelayData {
  final int id;
  RelayStatus status;
  int remainingTimeSeconds;
  DateTime? timerEndTime;
  bool fiveMinuteWarningSent;
  int? setTimerSeconds;

  // ✅ TAMBAHKAN FIELD INI
  // Untuk menyimpan item POS yang ditambahkan ke meja
  List<CartItem> posItems;

  RelayData({
    required this.id,
    this.status = RelayStatus.off,
    this.remainingTimeSeconds = 0,
    this.timerEndTime,
    this.fiveMinuteWarningSent = false,
    this.setTimerSeconds,
    this.posItems = const [], // ✅ Inisialisasi dengan list kosong
  });
}
