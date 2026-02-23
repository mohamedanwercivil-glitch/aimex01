import 'package:hive/hive.dart';

class DayRecordsStore {
  static final Box box = Hive.box('dayRecordsBox');

  static void addRecord(Map<String, dynamic> record) {
    box.add(record);
  }

  static List<Map<String, dynamic>> getAll() {
    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ❌ اقفل الحذف مؤقتًا عشان نختبر
  static void clear() {
    // box.clear();
  }
}