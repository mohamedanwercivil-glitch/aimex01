import 'package:hive/hive.dart';

class DayRecordsStore {
  static final Box box = Hive.box('dayRecordsBox');

  static void addRecord(Map<String, dynamic> record) {
    record['time'] = DateTime.now().toIso8601String();
    box.add(record);
  }

  static List<Map<String, dynamic>> getAll() {
    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> clear() async {
    await box.clear();
  }
}