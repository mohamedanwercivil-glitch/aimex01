import 'package:hive/hive.dart';

class CustomerStore {
  static final Box box = Hive.box('customerBox');

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
