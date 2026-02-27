import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

class InventoryStore {
  static final Box box = Hive.box('inventoryBox');

  // =========================
  // استيراد الأصناف من إكسيل (التنسيق: A:الاسم، B:الكمية، C:السعر)
  // =========================
  static Future<void> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      await box.clear();

      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet != null) {
        // نبدأ من 1 لتخطي العنوان (اسم الصنف، الكمية، سعر الشراء)
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.length < 3) continue;

          final name = row[0]?.value?.toString(); // العمود A
          final qty = double.tryParse(row[1]?.value?.toString() ?? '0'); // العمود B
          final buyPrice = double.tryParse(row[2]?.value?.toString() ?? '0'); // العمود C

          if (name != null && name.trim().isNotEmpty) {
            addItem(name.trim(), qty ?? 0, buyPrice ?? 0);
          }
        }
      }
    }
  }

  static void addItem(String name, double qty, double buyPrice) {
    final item = box.get(name);

    if (item != null) {
      final oldQty = (item['quantity'] as num).toDouble();
      final oldTotalCost = (item['totalCost'] as num).toDouble();

      final newQty = oldQty + qty;
      final newTotalCost = oldTotalCost + (qty * buyPrice);

      box.put(name, {
        'quantity': newQty,
        'totalCost': newTotalCost,
        'lastBuyPrice': buyPrice,
      });
    } else {
      box.put(name, {
        'quantity': qty,
        'totalCost': qty * buyPrice,
        'lastBuyPrice': buyPrice,
      });
    }
  }

  static bool sellItem(String name, double qty) {
    final item = box.get(name);
    if (item == null) return false;
    if ((item['quantity'] as num) < qty) return false;

    final newQty = (item['quantity'] as num) - qty;
    box.put(name, {
      'quantity': newQty,
      'totalCost': item['totalCost'],
      'lastBuyPrice': item['lastBuyPrice'],
    });
    return true;
  }
  
  static double getItemQty(String name) {
    final item = box.get(name);
    return (item != null) ? (item['quantity'] as num?)?.toDouble() ?? 0.0 : 0.0;
  }

  static List<Map<String, dynamic>> searchAvailableItems(String query) {
    return box.keys
        .where((key) => key.toString().toLowerCase().contains(query.toLowerCase()) && (box.get(key)['quantity'] as num) > 0)
        .map((key) {
      final item = box.get(key);
      return {
        'name': key,
        'qty': (item['quantity'] as num).toDouble(),
        'lastBuyPrice': (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> getAllItems() {
    return box.keys.map((key) {
      final item = box.get(key);
      return {
        'name': key,
        'quantity': (item['quantity'] as num).toDouble(),
        'lastBuyPrice': (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }
}
