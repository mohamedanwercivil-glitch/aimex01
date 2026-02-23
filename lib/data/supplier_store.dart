import 'package:hive/hive.dart';
import '../models/supplier.dart';

class SupplierStore {
  static const _boxName = 'suppliers';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

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
