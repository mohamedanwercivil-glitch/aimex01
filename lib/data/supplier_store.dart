import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/supplier.dart';
import '../utils/arabic_utils.dart';

class SupplierStore {
  static const _boxName = 'suppliers';
  static const _infoBoxName = 'suppliersInfo';
  static List<String> _cachedSuppliers = [];

  static Future<void> init() async {
    await Hive.openBox(_boxName);
    await Hive.openBox(_infoBoxName);
    refreshCache();
  }

  static void refreshCache() {
    _cachedSuppliers = _box.keys.map((k) => k.toString()).toList();
  }

  static Box get _box => Hive.box(_boxName);
  static Box get _infoBox => Hive.box(_infoBoxName);

  static Future<bool> importWithBalances() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) return false;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) return false;

      final oldDate = "2000-01-01T00:00:00";
      bool importedAny = false;
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;
        if (sheet.rows.isEmpty) continue;

        for (var i = 0; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          String name = row[0]?.value?.toString().trim() ?? "";
          if (name.isEmpty) continue;
          
          if (i == 0 && (name.contains('الاسم') || name.contains('المورد') || name.toLowerCase().contains('name'))) {
             continue;
          }

          final trimmedName = name.trim();
          
          double balance = 0.0;
          if (row.length > 2) {
            final debit = double.tryParse(row[1]?.value?.toString() ?? "0") ?? 0.0;
            final credit = double.tryParse(row[2]?.value?.toString() ?? "0") ?? 0.0;
            balance = credit - debit;
          }
          _box.put(trimmedName, balance);

          if (!_infoBox.containsKey(trimmedName)) {
            _infoBox.put(trimmedName, {'createdAt': oldDate});
          }
          
          importedAny = true;
        }
        if (importedAny) break;
      }
      refreshCache();
      return importedAny;
    } catch (e) {
      debugPrint("Import error: $e");
      return false;
    }
  }

  static List<Supplier> get suppliers {
    return _box.keys.map((name) => Supplier(name: name.toString())).toList();
  }

  static List<String> getAllSuppliers() {
    return _cachedSuppliers;
  }

  static void addSupplier(String name) {
    if (name.trim().isEmpty) return;
    final trimmedName = name.trim();
    if (!_box.containsKey(trimmedName)) {
      _box.put(trimmedName, 0.0);
      _infoBox.put(trimmedName, {
        'createdAt': DateTime.now().toIso8601String(),
      });
      refreshCache();
    }
  }

  static void updateBalance(String name, double amount) {
    final rawValue = _box.get(name.trim(), defaultValue: 0.0);
    double currentBalance = (rawValue is num) ? rawValue.toDouble() : 0.0;
    _box.put(name.trim(), currentBalance + amount);
  }

  static double getBalance(String name) {
    final rawValue = _box.get(name.trim(), defaultValue: 0.0);
    return (rawValue is num) ? rawValue.toDouble() : 0.0;
  }

  static Map<String, double> getAllBalances() {
    final Map<String, double> balances = {};
    for (var key in _box.keys) {
      balances[key.toString()] = getBalance(key.toString());
    }
    return balances;
  }

  static List<String> searchSuppliers(String query) {
    if (query.isEmpty) return _cachedSuppliers;
    final normalizedQuery = ArabicUtils.normalize(query);
    return _cachedSuppliers
        .where((s) => ArabicUtils.normalize(s).contains(normalizedQuery))
        .toList();
  }

  static List<String> getNewSuppliersToday(DateTime? startTime) {
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
