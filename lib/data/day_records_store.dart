import 'package:hive/hive.dart';
import 'inventory_store.dart';
import 'customer_store.dart';
import 'supplier_store.dart';

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

  static double? getLastItemSalePrice(String itemName) {
    final records = getAll().where((r) => r['type'] == 'sale' && r['item'] == itemName).toList();
    if (records.isEmpty) return null;
    // ترتيب السجلات حسب الوقت تنازلياً للحصول على الأحدث
    records.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));
    return (records.first['price'] as num?)?.toDouble();
  }

  static void reverseInvoiceEffects(String invoiceId) {
    final records = getAll().where((r) => r['invoiceId'] == invoiceId).toList();
    if (records.isEmpty) return;

    final first = records.first;
    final type = first['type'];

    if (type == 'sale') {
      final customer = first['customer'];
      final oldDue = first['dueAmount'] as double;
      CustomerStore.updateBalance(customer, -oldDue);
      for (var r in records) {
        if (r['isReturn'] == true) {
          InventoryStore.sellItem(r['item'], r['qty'] as double);
        } else {
          InventoryStore.returnItem(r['item'], r['qty'] as double);
        }
      }
    } else if (type == 'purchase') {
      final supplier = first['supplier'];
      final oldDue = first['dueAmount'] as double;
      SupplierStore.updateBalance(supplier, -oldDue);
      for (var r in records) {
        InventoryStore.sellItem(r['item'], r['qty'] as double);
      }
    }

    deleteRecordsByInvoiceId(invoiceId);
  }

  static void deleteRecordsByInvoiceId(String invoiceId) {
    final Map<dynamic, dynamic> allMap = box.toMap();
    final keysToDelete = [];
    allMap.forEach((key, value) {
      if (value['invoiceId'] == invoiceId) {
        keysToDelete.add(key);
      }
    });
    for (var key in keysToDelete) {
      box.delete(key);
    }
  }

  static int getNextInvoiceNumber(String type) {
    final records = getAll();
    final typeRecords = records.where((e) => e['type'] == type).toList();
    final uniqueInvoices = <String>{};
    for (var r in typeRecords) {
      if (r['invoiceId'] != null) uniqueInvoices.add(r['invoiceId']);
    }
    return uniqueInvoices.length + 1;
  }

  static Future<void> clear() async {
    await box.clear();
  }
}
