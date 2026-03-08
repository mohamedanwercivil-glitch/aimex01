import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class InventoryStore {
  static final Box box = Hive.box('inventoryBox');
  static List<Map<String, dynamic>> _cachedItems = [];

  // تحميل البيانات للذاكرة لتسريع البحث
  static void refreshCache() {
    _cachedItems = box.keys.map((key) {
      final item = box.get(key);
      return {
        'name': key,
        'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
        'lastBuyPrice': (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0,
        'createdAt': item['createdAt'],
      };
    }).toList();
  }

  static Future<void> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final oldDate = "2000-01-01T00:00:00"; 
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet != null) {
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          String getVal(int idx) {
            if (idx >= row.length || row[idx] == null || row[idx]!.value == null) return "";
            return row[idx]!.value.toString().trim();
          }

          final name = getVal(0);
          final qty = double.tryParse(getVal(1)) ?? 0.0;
          final buyPrice = double.tryParse(getVal(2)) ?? 0.0;

          if (name.isEmpty || name == 'اسم الصنف' || name == 'الصنف') continue;

          final existingItem = box.get(name);
          box.put(name, {
            'quantity': qty,
            'totalCost': qty * buyPrice,
            'lastBuyPrice': buyPrice,
            'createdAt': existingItem != null ? (existingItem['createdAt'] ?? oldDate) : oldDate,
          });
        }
      }
      refreshCache(); // تحديث الكاش بعد الاستيراد
    }
  }

  static void addItem(String name, double qty, double buyPrice) {
    final item = box.get(name);
    final now = DateTime.now().toIso8601String();

    if (item != null) {
      box.put(name, {
        'quantity': ((item['quantity'] as num?)?.toDouble() ?? 0.0) + qty,
        'totalCost': ((item['totalCost'] as num?)?.toDouble() ?? 0.0) + (qty * buyPrice),
        'lastBuyPrice': buyPrice,
        'createdAt': item['createdAt'] ?? now,
      });
    } else {
      box.put(name, {
        'quantity': qty,
        'totalCost': qty * buyPrice,
        'lastBuyPrice': buyPrice,
        'createdAt': now,
      });
    }
    refreshCache();
  }

  static bool sellItem(String name, double qty) {
    final item = box.get(name);
    if (item == null) return false;
    final currentQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    if (currentQty < qty) return false;

    box.put(name, {
      'quantity': currentQty - qty,
      'totalCost': (item['totalCost'] as num?)?.toDouble() ?? 0.0,
      'lastBuyPrice': (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0,
      'createdAt': item['createdAt'],
    });
    refreshCache();
    return true;
  }

  static void returnItem(String name, double qty) {
    final item = box.get(name);
    if (item == null) {
      addItem(name, qty, 0);
      return;
    }
    box.put(name, {
      'quantity': ((item['quantity'] as num?)?.toDouble() ?? 0.0) + qty,
      'totalCost': (item['totalCost'] as num?)?.toDouble() ?? 0.0,
      'lastBuyPrice': (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0,
      'createdAt': item['createdAt'],
    });
    refreshCache();
  }

  static double getItemQty(String name) => (box.get(name)?['quantity'] as num?)?.toDouble() ?? 0.0;
  static double getItemBuyPrice(String name) => (box.get(name)?['lastBuyPrice'] as num?)?.toDouble() ?? 0.0;

  static List<Map<String, dynamic>> getAllItems() {
    if (_cachedItems.isEmpty) refreshCache();
    return _cachedItems;
  }

  static List<Map<String, dynamic>> getNewItemsToday(DateTime? startTime) {
    if (startTime == null) return [];
    return getAllItems().where((item) {
      if (item['createdAt'] == null) return false;
      try {
        final createdAt = DateTime.parse(item['createdAt']);
        return createdAt.isAfter(startTime);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  static List<Map<String, dynamic>> searchAvailableItems(String query) {
    final lowerQuery = query.toLowerCase();
    return getAllItems().where((item) => 
      item['name'].toString().toLowerCase().contains(lowerQuery) &&
      (item['quantity'] as double) > 0
    ).toList();
  }
}
