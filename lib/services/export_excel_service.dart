import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';

class ExportExcelService {
  static Future<String> exportDay() async {
    var now = DateTime.now();
    String date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String time = "${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}";

    var excel = Excel.createExcel();
    var records = DayRecordsStore.getAll();

    excel.delete('Sheet1');

    // =========================
    // المبيعات
    // =========================
    var salesSheet = excel['المبيعات_$date'];
    var salesRecords = records.where((e) => e['type'] == 'sale').toList();

    // Group sales by invoice
    final salesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in salesRecords) {
      final key = record['invoiceId'] ??
          '${record['customer']}-${record['invoiceTotal']}-${record['paidAmount']}-${record['dueAmount']}';
      if (!salesByInvoice.containsKey(key)) {
        salesByInvoice[key] = [];
      }
      salesByInvoice[key]!.add(record);
    }

    var invoiceNum = 1;
    for (final invoiceItems in salesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;

      if (invoiceNum > 1) {
        salesSheet.appendRow([
          '----------------------------------------------------------------------------------------------------',
        ]);
      }

      salesSheet.appendRow(['فاتورة بيع رقم: $invoiceNum']);
      salesSheet.appendRow(['', '', 'اسم العميل', first['customer']]);
      salesSheet.appendRow(['', '', 'الصنف', 'العدد', 'السعر', 'جزئي']);

      int totalQty = 0;
      for (var item in invoiceItems) {
        salesSheet.appendRow([
          '',
          '',
          item['item'],
          item['qty'],
          item['price'],
          item['total']
        ]);
        totalQty += (item['qty'] as num).toInt();
      }

      salesSheet.appendRow([
        '',
        '',
        'اجمالي',
        totalQty,
        '',
        first['invoiceTotal'],
        'طريقة الدفع',
        first['paymentType'],
        'المبلغ المدفوع',
        first['paidAmount'],
        'الباقي',
        first['dueAmount']
      ]);

      salesSheet.appendRow([
        '',
        '',
        '',
        '',
        '',
        '',
        'الخزينه',
        first['wallet'],
      ]);

      invoiceNum++;
    }

    // =========================
    // المشتريات
    // =========================
    var purchasesSheet = excel['المشتريات_$date'];
    var purchaseRecords =
        records.where((e) => e['type'] == 'purchase').toList();

    // Group purchases by invoice
    final purchasesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in purchaseRecords) {
      final key = record['invoiceId'] ??
          '${record['supplier']}-${record['invoiceTotal']}-${record['paidAmount']}-${record['dueAmount']}';
      if (!purchasesByInvoice.containsKey(key)) {
        purchasesByInvoice[key] = [];
      }
      purchasesByInvoice[key]!.add(record);
    }

    var invoiceNumPurchase = 1;
    for (final invoiceItems in purchasesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;

      if (invoiceNumPurchase > 1) {
        purchasesSheet.appendRow([
          '----------------------------------------------------------------------------------------------------',
        ]);
      }

      purchasesSheet.appendRow(['فاتورة شراء رقم: $invoiceNumPurchase']);
      purchasesSheet.appendRow(['', '', 'اسم المورد', first['supplier']]);
      purchasesSheet.appendRow(['', '', 'الصنف', 'العدد', 'السعر', 'جزئي']);

      int totalQty = 0;
      for (var item in invoiceItems) {
        purchasesSheet.appendRow([
          '',
          '',
          item['item'],
          item['qty'],
          item['price'],
          item['total']
        ]);
        totalQty += (item['qty'] as num).toInt();
      }

      purchasesSheet.appendRow([
        '',
        '',
        'اجمالي',
        totalQty,
        '',
        first['invoiceTotal'],
        'طريقة الدفع',
        first['paymentType'],
        'المبلغ المدفوع',
        first['paidAmount'],
        'الباقي',
        first['dueAmount']
      ]);

      purchasesSheet.appendRow([
        '',
        '',
        '',
        '',
        '',
        '',
        'الخزينه',
        first['wallet'],
      ]);

      invoiceNumPurchase++;
    }

    // =========================
    // المصروفات
    // =========================
    var expenses = excel['المصروفات_$date'];
    expenses.appendRow(['المبلغ', 'البيان']);

    for (var r in records.where((e) => e['type'] == 'expense')) {
      expenses.appendRow([r['amount'], r['description']]);
    }

    // =========================
    // المسحوبات
    // =========================
    var withdraws = excel['المسحوبات_$date'];
    withdraws.appendRow(['المبلغ', 'اسم الشخص', 'البيان']);

    for (var r in records.where((e) => e['type'] == 'withdraw')) {
      withdraws.appendRow([r['amount'], r['person'], r['description']]);
    }

    // =========================
    // التحويلات
    // =========================
    var transfers = excel['التحويلات_$date'];
    transfers.appendRow(['من', 'إلى', 'المبلغ']);

    for (var r in records.where((e) => e['type'] == 'transfer')) {
      transfers.appendRow([r['from'], r['to'], r['amount']]);
    }

    // =========================
    // السداد
    // =========================
    var settlement = excel['سداد_$date'];
    settlement.appendRow(['العميل', 'المبلغ', 'طريقة الدفع', 'المحفظة']);

    for (var r in records.where((e) => e['type'] == 'settlement')) {
      settlement
          .appendRow([r['customer'], r['amount'], r['paymentType'], r['wallet']]);
    }

    // =========================
    // ملخص اليوم
    // =========================
    var summarySheet = excel['ملخص_$date'];

    final startOfDayCash = CashState.instance.startOfDayCash;
    final startOfDayWallets = CashState.instance.startOfDayWallets;
    final totalStartOfDayMoney = startOfDayCash +
        startOfDayWallets.values.fold(0.0, (sum, val) => sum + val);

    final totalSales =
        salesRecords.fold(0.0, (sum, r) => sum + (r['total'] as double));
    final totalPaidSales = salesByInvoice.values
        .fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as double));

    final totalDueSales = totalSales - totalPaidSales;

    final totalPurchases =
        purchaseRecords.fold(0.0, (sum, r) => sum + (r['total'] as double));

    final totalPaidPurchases = purchasesByInvoice.values
        .fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as double));

    final totalDuePurchases = totalPurchases - totalPaidPurchases;

    summarySheet.appendRow(['رصيد بداية اليوم']);
    summarySheet.appendRow(['اجمالي', totalStartOfDayMoney]);
    summarySheet.appendRow(['نقدي', startOfDayCash]);
    for (var entry in startOfDayWallets.entries) {
      summarySheet.appendRow([entry.key, entry.value]);
    }

    summarySheet.appendRow([]);

    summarySheet.appendRow(['المشتريات']);
    summarySheet.appendRow(['اجمالي المشتريات', totalPurchases]);
    summarySheet.appendRow(['اجمالي المدفوع', totalPaidPurchases]);
    summarySheet.appendRow(['اجمالي المتبقي', totalDuePurchases]);

    summarySheet.appendRow([]);

    summarySheet.appendRow(['المبيعات']);
    summarySheet.appendRow(['اجمالي المبيعات', totalSales]);
    summarySheet.appendRow(['اجمالي المستلم', totalPaidSales]);
    summarySheet.appendRow(['اجمالي المتبقي', totalDueSales]);

    summarySheet.appendRow([]);

    summarySheet.appendRow(['رصيد نهاية اليوم']);
    summarySheet.appendRow(['اجمالي', CashState.instance.totalMoney]);
    summarySheet.appendRow(['نقدي', CashState.instance.cash]);
    for (var entry in CashState.instance.wallets.entries) {
      summarySheet.appendRow([entry.key, entry.value]);
    }

    // =========================
    // حفظ آمن (Android Scoped Storage)
    // =========================

    final baseDir = await getExternalStorageDirectory();
    final aimexDir = Directory("${baseDir!.path}/AIMEX/$date");

    if (!await aimexDir.exists()) {
      await aimexDir.create(recursive: true);
    }

    final filePath = "${aimexDir.path}/تقرير_${date}_$time.xlsx";

    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!, flush: true);

    DayRecordsStore.clear();

    return filePath;
  }
}
