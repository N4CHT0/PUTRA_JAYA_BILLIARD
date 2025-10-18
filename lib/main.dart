// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
// Tambahkan import model Hive lain jika ada

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Inisialisasi Hive ---
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // --- 2. Daftarkan SEMUA Adapter ---
  Hive.registerAdapter(LocalProductAdapter());
  Hive.registerAdapter(LocalMemberAdapter());
  Hive.registerAdapter(LocalSupplierAdapter());
  Hive.registerAdapter(LocalTransactionAdapter());
  Hive.registerAdapter(LocalStockMutationAdapter());
  // ...daftarkan adapter lainnya jika ada...

  // --- 3. Buka SEMUA Box ---
  await Hive.openBox<LocalProduct>('products');
  await Hive.openBox<LocalMember>('members');
  await Hive.openBox<LocalSupplier>('suppliers');
  await Hive.openBox<LocalTransaction>('transactions');
  await Hive.openBox<LocalStockMutation>('stock_mutations');
  // ...buka box lainnya jika ada...

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
