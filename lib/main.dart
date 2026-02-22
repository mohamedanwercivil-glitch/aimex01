import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // =========================
  // Boxes الأساسية
  // =========================
  await Hive.openBox('dayBox');
  await Hive.openBox('transactionsBox');
  await Hive.openBox('inventoryBox');
  await Hive.openBox('customerBox');

  // =========================
  // Box خاص بتسجيل كل عمليات اليوم
  // =========================
  await Hive.openBox('dayRecordsBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
