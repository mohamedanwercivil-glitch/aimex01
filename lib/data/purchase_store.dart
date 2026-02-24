import 'package:uuid/uuid.dart';
import '../data/day_records_store.dart';
import '../models/purchase.dart';

class PurchaseStore {
  static final List<Purchase> _purchases = [];
  static const _uuid = Uuid();

  static void addPurchase(Purchase purchase, {String? invoiceId}) {
    final id = invoiceId ?? _uuid.v4();
    _purchases.add(purchase);

    DayRecordsStore.addRecord({
      'type': 'purchase',
      'invoiceId': id,
      'item': purchase.itemName,
      'qty': purchase.quantity,
      'price': purchase.purchasePrice,
      'total': purchase.quantity * purchase.purchasePrice,
      'supplier': purchase.supplierName,
      'invoiceTotal': purchase.invoiceTotal,
      'paidAmount': purchase.paidAmount,
      'dueAmount': purchase.dueAmount,
      'paymentType': purchase.paymentType,
      'wallet': purchase.wallet,
    });
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
