import 'package:hive/hive.dart';

class DraftStore {
  static final Box _salesBox = Hive.box('salesDraftBox');
  static final Box _purchasesBox = Hive.box('purchasesDraftBox');

  // =========================
  // المبيعات
  // =========================
  static void saveSalesDraft({
    required String customer,
    required String paymentType,
    required String? wallet,
    required String discount,
    required String paidAmount,
    required List<dynamic> items,
    Map<String, dynamic>? extra,
  }) {
    _salesBox.put('current', {
      'customer': customer,
      'paymentType': paymentType,
      'wallet': wallet,
      'discount': discount,
      'paidAmount': paidAmount,
      'items': items.map((e) {
        if (e is Map) return e;
        return {
          'name': e.name,
          'qty': e.qty,
          'price': e.price,
          'isReturn': e.isReturn,
        };
      }).toList(),
      if (extra != null) ...extra,
    });
  }

  static Map<String, dynamic>? getSalesDraft() {
    final data = _salesBox.get('current');
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  static void clearSalesDraft() {
    _salesBox.delete('current');
  }

  // =========================
  // المشتريات
  // =========================
  static void savePurchasesDraft({
    required String supplier,
    required String paymentType,
    required String? wallet,
    required String discount,
    required String paidAmount,
    required List<dynamic> items,
    Map<String, dynamic>? extra,
  }) {
    _purchasesBox.put('current', {
      'supplier': supplier,
      'paymentType': paymentType,
      'wallet': wallet,
      'discount': discount,
      'paidAmount': paidAmount,
      'items': items.map((e) {
        if (e is Map) return e;
        return {
          'name': e.name,
          'qty': e.qty,
          'price': e.price,
          'isReturn': e.isReturn,
        };
      }).toList(),
      if (extra != null) ...extra,
    });
  }

  static Map<String, dynamic>? getPurchasesDraft() {
    final data = _purchasesBox.get('current');
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  static void clearPurchasesDraft() {
    _purchasesBox.delete('current');
  }
}
