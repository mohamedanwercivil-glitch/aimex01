import 'package:hive/hive.dart';

class InventoryStore {
  static final Box box = Hive.box('inventoryBox');

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
