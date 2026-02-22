import '../models/supplier.dart';

class SupplierStore {
  static final List<Supplier> _suppliers = [];

  static List<Supplier> get suppliers => _suppliers;

  static void addSupplier(String name) {
    if (name.trim().isEmpty) return;

    final exists = _suppliers.any(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
    );

    if (!exists) {
      _suppliers.add(Supplier(name: name));
    }
  }

  static List<String> searchSuppliers(String query) {
    if (query.isEmpty) return [];

    return _suppliers
        .where((s) =>
        s.name.toLowerCase().startsWith(query.toLowerCase()))
        .map((s) => s.name)
        .toList();
  }
}
