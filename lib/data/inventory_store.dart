import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

class InventoryStore {
  static final Box box = Hive.box('inventoryBox');

  // =========================
  // Import from Excel
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

      // Clear existing inventory
      await box.clear();

      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet != null) {
        for (var i = 1; i < sheet.rows.length; i++) { // Start from 1 to skip header
          final row = sheet.rows[i];
          // Corrected column order based on the screenshot
          final buyPrice = double.tryParse(row[0]?.value.toString() ?? ''); // Column A
          final qty = double.tryParse(row[1]?.value.toString() ?? '');      // Column B
          final name = row[2]?.value.toString();                            // Column C

          if (name != null && qty != null && buyPrice != null) {
            addItem(name, qty, buyPrice);
          }
        }
      }
    }
  }

  // =========================
  // إضافة شراء
  // =========================
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
      });
    } else {
      box.put(name, {
        'quantity': qty,
        'totalCost': qty * buyPrice,
      });
    }
  }

  // =========================
  // بيع
  // =========================
  static bool sellItem(String name, double qty) {
    final item = box.get(name);

    if (item == null) return false;
    if ((item['quantity'] as num) < qty) return false;

    final newQty = (item['quantity'] as num) - qty;

    box.put(name, {
      'quantity': newQty,
      'totalCost': item['totalCost'],
    });

    return true;
  }
  
  // =========================
  // جلب كمية صنف معين
  // =========================
  static double getItemQty(String name) {
    final item = box.get(name);
    if (item != null) {
      return (item['quantity'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }


  // =========================
  // البحث في الأصناف المتاحة للبيع
  // =========================
  static List<Map<String, dynamic>> searchAvailableItems(String query) {
    return box.keys
        .where((key) =>
    key
        .toString()
        .toLowerCase()
        .contains(query.toLowerCase()) &&
        (box.get(key)['quantity'] as num) > 0)
        .map((key) {
      final item = box.get(key);
      final quantity = (item['quantity'] as num).toDouble();
      final totalCost = (item['totalCost'] as num).toDouble();

      double avgPrice = 0;
      if (quantity > 0) {
        avgPrice = totalCost / quantity;
      }

      return {
        'name': key,
        'qty': quantity,
        'avgPrice': avgPrice,
      };
    }).toList();
  }

  // =========================
  // جلب كل الأصناف
  // =========================
  static List<Map<String, dynamic>> getAllItems() {
    return box.keys.map((key) {
      final item = box.get(key);
      final quantity = (item['quantity'] as num).toDouble();
      final totalCost = (item['totalCost'] as num).toDouble();


      double avgPrice = 0;
      if (quantity > 0) {
        avgPrice = totalCost / quantity;
      }

      return {
        'name': key,
        'quantity': quantity,
        'avgPrice': avgPrice,
      };
    }).toList();
  }
}
