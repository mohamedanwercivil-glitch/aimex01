import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

const endOfDayTask = 'endOfDayTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == endOfDayTask) {
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
    return Future.value(true);
  });
}

class BackgroundService {
  static void initialize() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static void scheduleEndOfDayTask() {
    Workmanager().registerPeriodicTask(
      'endOfDayReminder',
      endOfDayTask,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 1), // Check shortly after start
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  static void cancelEndOfDayTask() {
    Workmanager().cancelByUniqueName('endOfDayReminder');
  }
}
