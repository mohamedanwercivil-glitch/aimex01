import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'backup_service.dart';

const endOfDayTask = 'endOfDayTask';
const autoBackupTask = 'autoBackupTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == autoBackupTask) {
        await Hive.initFlutter();
        final prefs = await SharedPreferences.getInstance();
        final dayStarted = prefs.getBool('dayStarted') ?? false;
        if (dayStarted) {
          await BackupService.createAutoSnapshot();
        }
      } else if (task == endOfDayTask) {
        final prefs = await SharedPreferences.getInstance();
        final dayStarted = prefs.getBool('dayStarted') ?? false;
        if (dayStarted) {
          final now = DateTime.now();
          if (now.hour >= 22) {
            NotificationService.showNotification(
              id: 0,
              title: 'لا تنسى إغلاق اليوم',
              body: 'لقد تجاوزت الساعة 10 مساءً. الرجاء إغلاق اليوم في أقرب وقت.',
            );
          }
        }
      }
    } catch (e) {
      // فشل صامت
    }
    return Future.value(true);
  });
}

class BackgroundService {
  static void initialize() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  // دالة لطلب استثناء البطارية لضمان العمل في الخلفية
  static Future<void> requestBatteryOptimizationExemption() async {
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  static void scheduleAutoBackup() {
    Workmanager().registerPeriodicTask(
      'periodicAutoBackup',
      autoBackupTask,
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(seconds: 10),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace, 
    );
  }

  static void scheduleEndOfDayTask() {
    Workmanager().registerPeriodicTask(
      'endOfDayReminder',
      endOfDayTask,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 1),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static void cancelEndOfDayTask() {
    Workmanager().cancelByUniqueName('endOfDayReminder');
  }

  static void cancelAllTasks() {
    Workmanager().cancelAll();
  }
}
