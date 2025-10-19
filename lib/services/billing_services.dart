// lib/services/billing_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class BillingService {
  // Variabel untuk menyimpan tarif yang sudah dimuat
  int _nightRateStartHour = 22;
  double _weekdayDayRate = 50000;
  double _weekdayNightRate = 60000;
  double _weekendDayRate = 65000;
  double _weekendNightRate = 75000;
  double _specialDayRate = 80000;
  double _specialNightRate = 90000;
  List<DateTime> _specialDates = [];

  // Muat semua tarif dari SharedPreferences
  Future<void> loadRates() async {
    final prefs = await SharedPreferences.getInstance();

    _nightRateStartHour = prefs.getInt('nightRateStartHour') ?? 22;

    _weekdayDayRate = prefs.getDouble('weekday_day_rate_per_hour') ?? 50000;
    _weekdayNightRate = prefs.getDouble('weekday_night_rate_per_hour') ?? 60000;

    _weekendDayRate = prefs.getDouble('weekend_day_rate_per_hour') ?? 65000;
    _weekendNightRate = prefs.getDouble('weekend_night_rate_per_hour') ?? 75000;

    _specialDayRate = prefs.getDouble('special_day_rate_per_hour') ?? 80000;
    _specialNightRate = prefs.getDouble('special_night_rate_per_hour') ?? 90000;

    final dateStrings = prefs.getStringList('specialDates') ?? [];
    _specialDates = dateStrings.map((date) => DateTime.parse(date)).toList();
  }

  // Menghitung total tagihan berdasarkan durasi dan tanggal mulai
  double calculateBilliardFee(Duration duration, {required DateTime date}) {
    // 1. Tentukan jenis hari (Weekday, Weekend, atau Spesial)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    bool isSpecial = _specialDates.contains(normalizedDate);
    bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    // 2. Tentukan jenis waktu (Siang atau Malam) berdasarkan WAKTU MULAI sesi
    bool isNightTime = date.hour >= _nightRateStartHour;

    // 3. Pilih tarif per jam yang sesuai
    double ratePerHour;
    if (isSpecial) {
      ratePerHour = isNightTime ? _specialNightRate : _specialDayRate;
    } else if (isWeekend) {
      ratePerHour = isNightTime ? _weekendNightRate : _weekendDayRate;
    } else {
      // Weekday
      ratePerHour = isNightTime ? _weekdayNightRate : _weekdayDayRate;
    }

    // 4. Hitung total biaya
    final totalSeconds = duration.inSeconds;
    final totalFee = (totalSeconds / 3600.0) * ratePerHour;

    // ✅ PERUBAHAN DI SINI: Terapkan pembulatan ke kelipatan 100 terdekat
    final roundedFee = (totalFee / 100).round() * 100.0;

    return roundedFee;
  }
}
