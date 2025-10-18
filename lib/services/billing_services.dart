// lib/services/billing_service.dart

import 'package:shared_preferences/shared_preferences.dart';

// Enum untuk tipe tarif
enum RateType { weekday, weekend, specialDay }

class BillingService {
  late SharedPreferences _prefs;

  // Variabel default jika SharedPreferences kosong
  double _weekdayRateHour = 50000, _weekdayRateMinute = 0;
  double _weekendRateHour = 65000, _weekendRateMinute = 0;
  double _specialDayRateHour = 80000, _specialDayRateMinute = 0;
  List<DateTime> _specialDates = [];

  // Memuat semua tarif dari SharedPreferences
  Future<void> loadRates() async {
    _prefs = await SharedPreferences.getInstance();

    _weekdayRateHour = _prefs.getDouble('weekdayRatePerHour') ?? 50000;
    _weekdayRateMinute = _prefs.getDouble('weekdayRatePerMinute') ?? 0;

    _weekendRateHour = _prefs.getDouble('weekendRatePerHour') ?? 65000;
    _weekendRateMinute = _prefs.getDouble('weekendRatePerMinute') ?? 0;

    _specialDayRateHour = _prefs.getDouble('specialDayRatePerHour') ?? 80000;
    _specialDayRateMinute = _prefs.getDouble('specialDayRatePerMinute') ?? 0;

    final dateStrings = _prefs.getStringList('specialDates') ?? [];
    _specialDates = dateStrings.map((date) => DateTime.parse(date)).toList();
  }

  // Menentukan tipe tarif berdasarkan tanggal (dengan prioritas)
  RateType getRateTypeForDate(DateTime date) {
    // Normalisasi tanggal (hapus info jam, menit, detik)
    final checkDate = DateTime(date.year, date.month, date.day);

    // Prioritas 1: Cek Hari Spesial
    if (_specialDates.contains(checkDate)) {
      return RateType.specialDay;
    }

    // Prioritas 2: Cek Weekend (Sabtu = 6, Minggu = 7)
    if (checkDate.weekday == DateTime.saturday ||
        checkDate.weekday == DateTime.sunday) {
      return RateType.weekend;
    }

    // Prioritas 3: Pasti Weekday
    return RateType.weekday;
  }

  // Menghitung total tagihan berdasarkan durasi dan tanggal
  double calculateBilliardFee(Duration duration, {DateTime? date}) {
    // Tentukan tanggal acuan (biasanya tanggal mulai main)
    final billingDate = date ?? DateTime.now();

    final rateType = getRateTypeForDate(billingDate);

    double ratePerHour;
    double ratePerMinute;

    // Pilih tarif yang sesuai
    switch (rateType) {
      case RateType.specialDay:
        ratePerHour = _specialDayRateHour;
        ratePerMinute = _specialDayRateMinute;
        break;
      case RateType.weekend:
        ratePerHour = _weekendRateHour;
        ratePerMinute = _weekendRateMinute;
        break;
      case RateType.weekday:
      default:
        ratePerHour = _weekdayRateHour;
        ratePerMinute = _weekdayRateMinute;
        break;
    }

    // Lakukan perhitungan
    double totalFee = 0;
    if (ratePerMinute > 0) {
      // Jika ada tarif per menit, gunakan itu (lebih presisi)
      totalFee = duration.inMinutes * ratePerMinute;
      // Atau bisa dibuat lebih presisi lagi per detik jika mau:
      // totalFee = (duration.inSeconds / 60) * ratePerMinute;
    } else {
      // Jika tidak, hitung proporsional per jam (presisi per detik)
      totalFee = (duration.inSeconds / 3600) * ratePerHour;
    }

    // Pembulatan (opsional, sesuaikan dengan aturan bisnis Anda)
    // Contoh: bulatkan ke atas ke kelipatan 500 terdekat
    // if (totalFee > 0) {
    //   totalFee = (totalFee / 500).ceil() * 500;
    // } else {
    //   totalFee = 0; // Pastikan tidak negatif
    // }

    // Atau bulatkan ke 2 desimal jika pakai tarif menit
    // totalFee = double.parse(totalFee.toStringAsFixed(2));

    // Atau bulatkan ke integer terdekat
    totalFee = totalFee.roundToDouble();

    return totalFee;
  }
}
