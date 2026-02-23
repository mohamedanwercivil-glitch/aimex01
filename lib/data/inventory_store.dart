import 'package:hive/hive.dart';

class InventoryStore {
  static final Box box = Hive.box('inventoryBox');

  // =========================
  // إضافة شراء
  // =========================
  static void addItem(String name, int qty, double buyPrice) {
    final item = box.get(name);

    if (item != null) {
      final oldQty = item['quantity'];
      final oldTotalCost = item['totalCost'];

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
  static bool sellItem(String name, int qty) {
    final item = box.get(name);

    if (item == null) return false;
    if (item['quantity'] < qty) return false;

    final newQty = item['quantity'] - qty;

    box.put(name, {
      'quantity': newQty,
      'totalCost': item['totalCost'],
    });

    return true;
  }
  
  // =========================
  // جلب كمية صنف معين
  // =========================
  static int getItemQty(String name) {
    final item = box.get(name);
    if (item != null) {
      return item['quantity'] ?? 0;
    }
    return 0;
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
        box.get(key)['quantity'] > 0)
        .map((key) {
      final item = box.get(key);

      double avgPrice = 0;
      if (item['quantity'] > 0) {
        avgPrice = item['totalCost'] / item['quantity'];
      }

      return {
        'name': key,
        'quantity': item['quantity'],
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

      double avgPrice = 0;
      if (item['quantity'] > 0) {
        avgPrice = item['totalCost'] / item['quantity'];
      }

      return {
        'name': key,
        'quantity': item['quantity'],
        'avgPrice': avgPrice,
      };
    }).toList();
  }
}
