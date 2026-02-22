import '../models/purchase.dart';

class PurchaseStore {
  static final List<Purchase> _purchases = [];

  static void addPurchase(Purchase purchase) {
    _purchases.add(purchase);
  }

  static List<Purchase> getAllPurchases() {
    return List.unmodifiable(_purchases);
  }

  static List<Purchase> getTodayPurchases() {
    final today = DateTime.now();
    return _purchases.where((p) {
      return p.date.year == today.year &&
          p.date.month == today.month &&
          p.date.day == today.day;
    }).toList();
  }

  static List<Purchase> getPurchasesBySupplier(String supplierName) {
    return _purchases
        .where((p) => p.supplierName == supplierName)
        .toList();
  }

  static List<Purchase> getPurchasesByItem(String itemName) {
    return _purchases
        .where((p) => p.itemName == itemName)
        .toList();
  }
}
