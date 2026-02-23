import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'data/supplier_store.dart';
import 'screens/home_screen.dart';
import 'state/day_state.dart';
import 'state/cash_state.dart';

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
  await SupplierStore.init();

  // =========================
  // Box خاص بتسجيل كل عمليات اليوم
  // =========================
  await Hive.openBox('dayRecordsBox');

  // Initialize states AFTER opening boxes
  DayState.instance;
  CashState.instance;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: DayState.instance,
        ),
        ChangeNotifierProvider.value(
          value: CashState.instance,
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomeScreen(),
      ),
    );
  }
}