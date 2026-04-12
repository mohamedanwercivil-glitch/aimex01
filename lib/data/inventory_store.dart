import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../utils/arabic_utils.dart';
import '../services/logger_service.dart';

class InventoryStore {
  static final Box box = Hive.box('inventoryBox');
  static List<Map<String, dynamic>> _cachedItems = [];

  static void refreshCache() {
    final List<Map<String, dynamic>> items = [];
    for (var key in box.keys) {
      final rawData = box.get(key);
      if (rawData == null) continue;
      
      final item = Map<String, dynamic>.from(rawData);
      final List<dynamic> purchases = item['purchases'] ?? [];
      
      double totalQty = 0;
      double totalCost = 0;
      double lastPrice = (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0;

      for (var p in purchases) {
        double q = (p['qty'] as num).toDouble();
        double pr = (p['price'] as num).toDouble();
        totalQty += q;
        totalCost += (q * pr);
      }

      double avgPrice = totalQty > 0 ? totalCost / totalQty : lastPrice;

      items.add({
        'name': key,
        'quantity': totalQty,
        'lastBuyPrice': lastPrice,
        'avgBuyPrice': avgPrice, 
        'createdAt': item['createdAt'],
      });
    }
    _cachedItems = items;
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
            'purchases': [{'qty': qty, 'price': buyPrice}],
            'lastBuyPrice': buyPrice,
            'createdAt': existingItem != null ? (existingItem['createdAt'] ?? oldDate) : oldDate,
          });
        }
      }
      refreshCache();
    }
  }

  static void addItem(String name, double qty, double buyPrice, [String reason = "إضافة صنف/شراء"]) {
    double before = getItemQty(name);
    final rawItem = box.get(name);
    final now = DateTime.now().toIso8601String();
    
    Map<String, dynamic> item = rawItem != null ? Map<String, dynamic>.from(rawItem) : {};
    List<Map<String, dynamic>> purchases = (item['purchases'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    purchases.add({'qty': qty, 'price': buyPrice});

    box.put(name, {
      'purchases': purchases,
      'lastBuyPrice': buyPrice,
      'createdAt': item['createdAt'] ?? now,
    });
    
    refreshCache();
    double after = getItemQty(name);
    LoggerService.logInventoryChange(
      itemName: name,
      qtyChange: qty,
      before: before,
      after: after,
      reason: reason,
    );
  }

  static void updateItem(String name, double newQty, double newPrice) {
    double before = getItemQty(name);
    final rawItem = box.get(name);
    if (rawItem == null) return;

    final now = DateTime.now().toIso8601String();
    Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
    
    List<Map<String, dynamic>> purchases = [{'qty': newQty, 'price': newPrice}];

    box.put(name, {
      'purchases': purchases,
      'lastBuyPrice': newPrice,
      'createdAt': item['createdAt'] ?? now,
    });
    
    refreshCache();
    double after = getItemQty(name);
    LoggerService.logInventoryChange(
      itemName: name,
      qtyChange: after - before,
      before: before,
      after: after,
      reason: "تحديث يدوي للكمية والسعر",
    );
  }

  static bool sellItem(String name, double qtyToSell, [String reason = "بيع صنف"]) {
    double before = getItemQty(name);
    final rawItem = box.get(name);
    if (rawItem == null) return false;

    Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
    List<Map<String, dynamic>> purchases = (item['purchases'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    double totalAvailable = purchases.fold(0, (sum, p) => sum + (p['qty'] as num).toDouble());
    if (totalAvailable < qtyToSell) return false;

    double remainingToSell = qtyToSell;
    while (remainingToSell > 0 && purchases.isNotEmpty) {
      double oldestQty = (purchases[0]['qty'] as num).toDouble();
      
      if (oldestQty <= remainingToSell) {
        remainingToSell -= oldestQty;
        purchases.removeAt(0); 
      } else {
        purchases[0]['qty'] = oldestQty - remainingToSell;
        remainingToSell = 0;
      }
    }

    box.put(name, {
      'purchases': purchases,
      'lastBuyPrice': item['lastBuyPrice'],
      'createdAt': item['createdAt'],
    });

    refreshCache();
    double after = getItemQty(name);
    LoggerService.logInventoryChange(
      itemName: name,
      qtyChange: -qtyToSell,
      before: before,
      after: after,
      reason: reason,
    );
    return true;
  }

  static void returnItem(String name, double qty, [String reason = "مرتجع صنف"]) {
    double before = getItemQty(name);
    final rawItem = box.get(name);
    if (rawItem == null) {
      addItem(name, qty, 0, reason);
      return;
    }

    Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
    List<Map<String, dynamic>> purchases = (item['purchases'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    purchases.add({'qty': qty, 'price': item['lastBuyPrice'] ?? 0.0});

    box.put(name, {
      'purchases': purchases,
      'lastBuyPrice': item['lastBuyPrice'],
      'createdAt': item['createdAt'],
    });
    
    refreshCache();
    double after = getItemQty(name);
    LoggerService.logInventoryChange(
      itemName: name,
      qtyChange: qty,
      before: before,
      after: after,
      reason: reason,
    );
  }

  static double getItemQty(String name) {
    final rawItem = box.get(name);
    if (rawItem == null) return 0.0;
    final List purchases = rawItem['purchases'] ?? [];
    return purchases.fold(0.0, (sum, p) => sum + (p['qty'] as num).toDouble());
  }

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

  static List<String> searchItemNames(String query) {
    final normalizedQuery = ArabicUtils.normalize(query);
    return getAllItems()
        .where((item) => ArabicUtils.normalize(item['name'].toString()).contains(normalizedQuery))
        .map((item) => "${item['name']} | المتاح: ${item['quantity']} | آخر سعر: ${item['lastBuyPrice']}")
        .toList();
  }

  static List<String> searchAvailableItemNames(String query) {
    final normalizedQuery = ArabicUtils.normalize(query);
    return getAllItems()
        .where((item) => 
          ArabicUtils.normalize(item['name'].toString()).contains(normalizedQuery) &&
          (item['quantity'] as double) > 0
        )
        .map((item) => "${item['name']} | المتاح: ${item['quantity']} | آخر سعر: ${item['lastBuyPrice']}")
        .toList();
  }
}
