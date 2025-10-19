// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:putra_jaya_billiard/models/product_variant.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:putra_jaya_billiard/auth_wrapper.dart';

// --- 1. Import SEMUA Model Hive & Adapternya ---
import 'models/local_product.dart';
import 'models/local_member.dart';
import 'models/local_supplier.dart';
import 'models/local_transaction.dart';
import 'models/local_stock_mutation.dart';
import 'models/local_payment_method.dart'; // ✅ IMPORT MODEL BARU

// Import service Anda
import 'services/local_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Inisialisasi Hive ---
  // Inisialisasi path tidak lagi diperlukan dengan initFlutter() versi baru,
  // tapi tidak masalah jika tetap ada.
  await Hive.initFlutter();

  // --- 2. Daftarkan SEMUA Adapter ---
  Hive.registerAdapter(LocalProductAdapter());
  Hive.registerAdapter(LocalMemberAdapter());
  Hive.registerAdapter(LocalSupplierAdapter());
  Hive.registerAdapter(LocalTransactionAdapter());
  Hive.registerAdapter(LocalStockMutationAdapter());
  Hive.registerAdapter(LocalPaymentMethodAdapter()); // ✅ DAFTARKAN ADAPTER BARU
  Hive.registerAdapter(ProductVariantAdapter());

  // --- 3. Panggil Service untuk Membuka Semua Box ---
  // Ini lebih rapi daripada membuka box satu per satu di sini.
  await LocalDatabaseService.init();

  // --- Inisialisasi Firebase (jika masih diperlukan untuk Auth) ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- Inisialisasi Window Manager ---
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1024, 650),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  // --- Akhir Inisialisasi Window Manager ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Putra Jaya Billiard',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Poppins',
            ),
        primaryColor: Colors.tealAccent,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}
