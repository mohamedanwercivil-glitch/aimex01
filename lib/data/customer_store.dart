import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

class CustomerStore {
  static final Box box = Hive.box('customerBox');

  // =========================
  // استيراد العملاء وأرصدتهم من إكسيل
  // التنسيق حسب ملف المستخدم: A:الاسم، B:مدين (0)، C:دائن (المبلغ اللي ليا عنده)
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
          final colB = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
          final colC = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;

          if (name != null && name.trim().isNotEmpty) {
            // حسب ملف المستخدم: عمود C هو "ليا عنده" (الرصيد الموجب)
            // الرصيد = C - B ليكون الناتج 49099.5 (عليه فلوس)
            final balance = colC - colB;
            
            // مسح القيمة القديمة وتحديثها بالرصيد الجديد من الإكسيل
            box.put(name.trim(), balance);
          }
        }
      }
    }
  }

  static void addCustomer(String name) {
    if (name.trim().isEmpty) return;
    if (!box.containsKey(name.trim())) {
      box.put(name.trim(), 0.0);
    }
  }

  static void updateBalance(String name, double amount) {
    final rawValue = box.get(name.trim(), defaultValue: 0.0);
    double currentBalance = 0.0;
    
    if (rawValue is num) {
      currentBalance = rawValue.toDouble();
    }
    
    box.put(name.trim(), currentBalance + amount);
  }

  static double getBalance(String name) {
    final rawValue = box.get(name.trim(), defaultValue: 0.0);
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    return 0.0;
  }

  static List<String> searchCustomers(String query) {
    return box.keys
        .where((key) => key.toString().toLowerCase().contains(query.toLowerCase()))
        .map((key) => key.toString())
        .toList();
  }

  static List<String> getAllCustomers() {
    return box.keys.map((key) => key.toString()).toList();
  }
}
