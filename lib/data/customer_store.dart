import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../utils/arabic_utils.dart';

class CustomerStore {
  static final Box box = Hive.box('customerBox');
  static const _infoBoxName = 'customerInfoBox';
  static List<String> _cachedCustomers = [];

  static Future<void> init() async {
    await Hive.openBox(_infoBoxName);
    refreshCache(); // تحميل الأسماء في الذاكرة عند بدء التشغيل
  }

  static void refreshCache() {
    _cachedCustomers = box.keys.map((k) => k.toString()).toList();
  }

  static Box get _infoBox => Hive.box(_infoBoxName);

  static Future<void> importWithBalances() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];
      
      final oldDate = "2000-01-01T00:00:00";

      if (sheet != null) {
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;
          final name = row[0]?.value?.toString();
          if (name != null && name.trim().isNotEmpty) {
            double balance = 0.0;
            if (row.length > 1) {
              balance += double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
            }
            if (row.length > 2) {
              balance -= double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
            }
            
            final trimmedName = name.trim();
            box.put(trimmedName, balance);
            
            if (!_infoBox.containsKey(trimmedName)) {
              _infoBox.put(trimmedName, {'createdAt': oldDate});
            }
          }
        }
      }
      refreshCache(); // تحديث الكاش بعد الاستيراد
    }
  }

  static void addCustomer(String name) {
    if (name.trim().isEmpty) return;
    final trimmedName = name.trim();
    if (!box.containsKey(trimmedName)) {
      box.put(trimmedName, 0.0);
      _infoBox.put(trimmedName, {
        'createdAt': DateTime.now().toIso8601String(),
      });
      refreshCache(); // تحديث الكاش عند إضافة عميل جديد
    }
  }

  static void updateBalance(String name, double amount) {
    final rawValue = box.get(name.trim(), defaultValue: 0.0);
    double currentBalance = (rawValue is num) ? rawValue.toDouble() : 0.0;
    box.put(name.trim(), currentBalance + amount);
  }

  static double getBalance(String name) {
    final rawValue = box.get(name.trim(), defaultValue: 0.0);
    return (rawValue is num) ? rawValue.toDouble() : 0.0;
  }

  static List<String> searchCustomers(String query) {
    if (query.isEmpty) return _cachedCustomers;
    final normalizedQuery = ArabicUtils.normalize(query);
    return _cachedCustomers
        .where((key) => ArabicUtils.normalize(key).contains(normalizedQuery))
        .toList();
  }

  static List<String> getAllCustomers() {
    return _cachedCustomers;
  }

  static List<String> getNewCustomersToday(DateTime? startTime) {
    if (startTime == null) return [];
    return _infoBox.keys.where((key) {
      final info = _infoBox.get(key);
      if (info == null || info['createdAt'] == null) return false;
      try {
        final createdAt = DateTime.parse(info['createdAt']);
        return createdAt.isAfter(startTime);
      } catch (_) {
        return false;
      }
    }).map((e) => e.toString()).toList();
  }
}
