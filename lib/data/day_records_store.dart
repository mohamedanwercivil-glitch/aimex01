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

  static int getNextInvoiceNumber(String type) {
    final records = getAll();
    final typeRecords = records.where((e) => e['type'] == type).toList();
    
    // تجميع العناصر حسب invoiceId للحصول على عدد الفواتير الفريدة
    final uniqueInvoices = <String>{};
    for (var r in typeRecords) {
      if (r['invoiceId'] != null) {
        uniqueInvoices.add(r['invoiceId']);
      }
    }
    
    return uniqueInvoices.length + 1;
  }

  static Future<void> clear() async {
    await box.clear();
  }
}
