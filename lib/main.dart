import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'data/supplier_store.dart';
import 'data/customer_store.dart';
import 'screens/home_screen.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'services/logger_service.dart';
import 'services/backup_service.dart';
import 'state/day_state.dart';
import 'state/cash_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Logger
  await LoggerService.init();

  // 2. Initialize Background & Notifications
  await NotificationService.initialize(); 
  BackgroundService.initialize();
  
  // 3. Schedule Background Tasks (Backup every 30m)
  BackgroundService.scheduleAutoBackup();
  BackgroundService.scheduleEndOfDayTask();

  // 4. Start Internal Timer (Extra protection when app is open)
  BackupService.startAutoBackupTimer();

  await Hive.initFlutter();

  // 5. Open Boxes
  await Hive.openBox('dayBox');
  await Hive.openBox('transactionsBox');
  await Hive.openBox('inventoryBox');
  await Hive.openBox('customerBox');
  await Hive.openBox('dayRecordsBox');
  await Hive.openBox('salesDraftBox');
  await Hive.openBox('purchasesDraftBox');
  await SupplierStore.init();
  await CustomerStore.init();

  // 6. Initialize States
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
