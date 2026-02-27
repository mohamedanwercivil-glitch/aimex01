import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import '../models/supplier.dart';

class SupplierStore {
  static const _boxName = 'suppliers';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  // =========================
  // استيراد الموردين من إكسيل (العمود A بدءاً من الصف 2)
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

      await _box.clear();

      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet != null) {
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final name = row[0]?.value?.toString(); // العمود A
          if (name != null && name.trim().isNotEmpty) {
            addSupplier(name.trim());
          }
        }
      }
    }
  }

  static List<Supplier> get suppliers {
    return _box.values.map((name) => Supplier(name: name)).toList();
  }

  static void addSupplier(String name) {
    if (name.trim().isEmpty) return;

    final lowerCaseName = name.toLowerCase();
    if (!_box.values.any((s) => s.toLowerCase() == lowerCaseName)) {
      _box.add(name);
    }
  }

  static List<String> searchSuppliers(String query) {
    if (query.isEmpty) return [];

    return _box.values
        .where((s) => s.toLowerCase().startsWith(query.toLowerCase()))
        .toList();
  }
}
