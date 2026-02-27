import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import '../models/supplier.dart';

class SupplierStore {
  static const _boxName = 'suppliers';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  // =========================
  // استيراد الموردين وأرصدتهم من إكسيل
  // التنسيق حسب ملف المستخدم: A:الاسم، B:دائن (ليه فلوس)، C:مدين (0)
  // =========================
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

      if (sheet != null) {
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final name = row[0]?.value?.toString();
          final colB = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0; // دائن (ليه)
          final colC = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0; // مدين (عليه)

          if (name != null && name.trim().isNotEmpty) {
            // رصيد المورد = دائن - مدين (المبلغ اللي ليه فعلياً)
            final balance = colB - colC;
            
            // تحديث الرصيد مباشرة من ملف الإكسيل
            _box.put(name.trim(), balance);
          }
        }
      }
    }
  }

  static List<Supplier> get suppliers {
    return _box.keys.map((name) => Supplier(name: name.toString())).toList();
  }

  static void addSupplier(String name) {
    if (name.trim().isEmpty) return;
    if (!_box.containsKey(name.trim())) {
      _box.put(name.trim(), 0.0);
    }
  }

  static void updateBalance(String name, double amount) {
    final rawValue = _box.get(name.trim(), defaultValue: 0.0);
    double currentBalance = 0.0;
    
    if (rawValue is num) {
      currentBalance = rawValue.toDouble();
    }
    
    _box.put(name.trim(), currentBalance + amount);
  }

  static double getBalance(String name) {
    final rawValue = _box.get(name.trim(), defaultValue: 0.0);
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    return 0.0;
  }

  static List<String> searchSuppliers(String query) {
    if (query.isEmpty) return [];
    return _box.keys
        .where((s) => s.toString().toLowerCase().contains(query.toLowerCase()))
        .map((e) => e.toString())
        .toList();
  }
}
