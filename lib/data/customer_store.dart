import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

class CustomerStore {
  static final Box box = Hive.box('customerBox');

  // =========================
  // استيراد العملاء من إكسيل (العمود A بدءاً من الصف 2)
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
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final name = row[0]?.value?.toString(); // العمود A
          if (name != null && name.trim().isNotEmpty) {
            addCustomer(name.trim());
          }
        }
      }
    }
  }

  static void addCustomer(String name) {
    if (!box.containsKey(name)) {
      box.put(name, true);
    }
  }

  static List<String> searchCustomers(String query) {
    return box.keys
        .where((key) =>
        key.toString().toLowerCase().contains(query.toLowerCase()))
        .map((key) => key.toString())
        .toList();
  }

  static List<String> getAllCustomers() {
    return box.keys.map((key) => key.toString()).toList();
  }
}
