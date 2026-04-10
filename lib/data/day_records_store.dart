import 'package:hive/hive.dart';
import 'inventory_store.dart';
import 'customer_store.dart';
import 'supplier_store.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';

class DayRecordsStore {
  static final Box box = Hive.box('dayRecordsBox');

  static void addRecord(Map<String, dynamic> record) {
    record['time'] = DateTime.now().toIso8601String();
    box.add(record);
  }

  static List<Map<String, dynamic>> getAll() {
    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static double? getLastItemSalePrice(String itemName) {
    final records = getAll().where((r) => r['type'] == 'sale' && r['item'] == itemName).toList();
    if (records.isEmpty) return null;
    records.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));
    return (records.first['price'] as num?)?.toDouble();
  }

  static void reverseInvoiceEffects(String invoiceId) {
    final allRecords = getAll();
    final records = allRecords.where((r) => r['invoiceId'] == invoiceId || r['id'] == invoiceId).toList();
    if (records.isEmpty) return;

    // Group records by type to handle them correctly
    final groupedByType = <String, List<Map<String, dynamic>>>{};
    for (var r in records) {
      final type = r['type'] as String;
      groupedByType.putIfAbsent(type, () => []).add(r);
    }

    groupedByType.forEach((type, typeRecords) {
      switch (type) {
        case 'sale':
          _reverseSale(typeRecords);
          break;
        case 'purchase':
          _reversePurchase(typeRecords);
          break;
        case 'sales_return':
          _reverseSalesReturn(typeRecords);
          break;
        case 'expense':
          for (var r in typeRecords) _reverseExpense(r);
          break;
        case 'withdraw':
          for (var r in typeRecords) _reverseWithdraw(r);
          break;
        case 'settlement':
          for (var r in typeRecords) _reverseSettlement(r);
          break;
        case 'supplier_settlement':
          for (var r in typeRecords) _reverseSupplierSettlement(r);
          break;
        case 'transfer':
          for (var r in typeRecords) _reverseTransfer(r);
          break;
      }
    });

    deleteRecordsById(invoiceId);
  }

  static void _reverseSale(List<Map<String, dynamic>> records) {
    final first = records.first;
    final customer = first['customer'];
    final dueAmount = (first['dueAmount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (first['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentType = first['paymentType'] ?? 'كاش';
    final wallet = first['wallet'];

    CustomerStore.updateBalance(customer, -dueAmount);

    if (paidAmount != 0) {
      FinanceService.withdraw(
        amount: paidAmount.abs(),
        paymentType: (paymentType == 'تحويل') ? 'تحويل' : 'كاش',
        walletName: (paymentType == 'تحويل') ? wallet : null,
        allowNegative: true,
      );
      DayState.instance.addSale(-paidAmount);
    }

    for (var r in records) {
      if (r['isReturn'] == true) {
        InventoryStore.sellItem(r['item'], (r['qty'] as num).toDouble());
      } else {
        InventoryStore.returnItem(r['item'], (r['qty'] as num).toDouble());
      }
    }
  }

  static void _reversePurchase(List<Map<String, dynamic>> records) {
    final first = records.first;
    final supplier = first['supplier'];
    final dueAmount = (first['dueAmount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (first['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentType = first['paymentType'] ?? 'كاش';
    final wallet = first['wallet'];

    SupplierStore.updateBalance(supplier, -dueAmount);

    if (paidAmount != 0) {
      FinanceService.deposit(
        amount: paidAmount.abs(),
        paymentType: (paymentType == 'تحويل') ? 'تحويل' : 'كاش',
        walletName: (paymentType == 'تحويل') ? wallet : null,
      );
    }

    for (var r in records) {
      InventoryStore.sellItem(r['item'], (r['qty'] as num).toDouble());
    }
  }

  static void _reverseSalesReturn(List<Map<String, dynamic>> records) {
    final first = records.first;
    final customer = first['customer'];
    final refundAmount = (first['refundAmount'] as num?)?.toDouble() ?? 0.0;
    final totalReturn = (first['invoiceTotal'] as num?)?.toDouble() ?? 0.0;
    final wallet = first['wallet'];

    final netCreditToCustomer = totalReturn - refundAmount;
    CustomerStore.updateBalance(customer, netCreditToCustomer);

    if (refundAmount > 0) {
      FinanceService.deposit(
        amount: refundAmount,
        paymentType: first['refundType'] == 'تحويل' ? 'تحويل' : 'كاش',
        walletName: first['refundType'] == 'تحويل' ? wallet : null,
      );
    }

    for (var r in records) {
      InventoryStore.sellItem(r['item'], (r['qty'] as num).toDouble());
    }
  }

  static void _reverseExpense(Map<String, dynamic> record) {
    final amount = (record['amount'] as num).toDouble();
    FinanceService.deposit(
      amount: amount,
      paymentType: record['wallet'] == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: record['wallet'] == 'نقدي' ? null : record['wallet'],
    );
    DayState.instance.addExpense(-amount);
  }

  static void _reverseWithdraw(Map<String, dynamic> record) {
    final amount = (record['amount'] as num).toDouble();
    final wallet = record['wallet'] ?? record['source'] ?? 'نقدي';
    FinanceService.deposit(
      amount: amount,
      paymentType: wallet == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: wallet == 'نقدي' ? null : wallet,
    );
  }

  static void _reverseSettlement(Map<String, dynamic> record) {
    final amount = (record['amount'] as num).toDouble();
    final customer = record['customer'];
    CustomerStore.updateBalance(customer, amount);
    FinanceService.withdraw(
      amount: amount,
      paymentType: record['wallet'] == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: record['wallet'] == 'نقدي' ? null : record['wallet'],
      allowNegative: true,
    );
  }

  static void _reverseSupplierSettlement(Map<String, dynamic> record) {
    final amount = (record['amount'] as num).toDouble();
    final supplier = record['supplier'];
    SupplierStore.updateBalance(supplier, amount);
    FinanceService.deposit(
      amount: amount,
      paymentType: record['wallet'] == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: record['wallet'] == 'نقدي' ? null : record['wallet'],
    );
  }

  static void _reverseTransfer(Map<String, dynamic> record) {
    final amount = (record['amount'] as num).toDouble();
    final fee = (record['fee'] as num?)?.toDouble() ?? 0.0;
    final from = record['from'];
    final to = record['to'];

    FinanceService.deposit(
      amount: amount + fee,
      paymentType: from == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: from == 'نقدي' ? null : from,
    );

    FinanceService.withdraw(
      amount: amount,
      paymentType: to == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: to == 'نقدي' ? null : to,
      allowNegative: true,
    );
  }

  static void deleteRecordsById(String id) {
    final Map<dynamic, dynamic> allMap = box.toMap();
    final keysToDelete = [];
    allMap.forEach((key, value) {
      if (value['invoiceId'] == id || value['id'] == id) {
        keysToDelete.add(key);
      }
    });
    for (var key in keysToDelete) {
      box.delete(key);
    }
  }

  static int getNextInvoiceNumber(String type) {
    final records = getAll();
    final typeRecords = records.where((e) => e['type'] == type).toList();
    final uniqueInvoices = <String>{};
    for (var r in typeRecords) {
      if (r['invoiceId'] != null) uniqueInvoices.add(r['invoiceId']);
    }
    return uniqueInvoices.length + 1;
  }

  static Future<void> clear() async {
    await box.clear();
  }
}
