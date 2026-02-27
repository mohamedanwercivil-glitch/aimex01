import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive_io.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';

class ExportExcelService {
  static Future<Map<String, String>> exportDayWithInvoices() async {
    final excelPath = await exportDay();
    final zipPath = await zipDailyInvoices();
    
    return {
      'excel': excelPath,
      'zip': zipPath,
    };
  }

  static Future<String> zipDailyInvoices() async {
    var now = DateTime.now();
    String reportDate = DateFormat('dd-MM-yyyy').format(now);
    
    final appDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${appDir.path}/daily_invoices');
    
    if (!await invoicesDir.exists() || (await invoicesDir.list().isEmpty)) {
      return "";
    }

    final encoder = ZipFileEncoder();
    final zipPath = '${appDir.path}/فواتير_مبيعات_$reportDate.zip';
    encoder.create(zipPath);
    
    await for (final file in invoicesDir.list()) {
      if (file is File && file.path.endsWith('.pdf')) {
        encoder.addFile(file);
      }
    }
    encoder.close();
    
    return zipPath;
  }

  // دالة لمسح الفواتير بعد الانتهاء من إرسالها لليوم الجديد
  static Future<void> clearDailyInvoices() async {
    final appDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${appDir.path}/daily_invoices');
    if (await invoicesDir.exists()) {
      await invoicesDir.delete(recursive: true);
    }
  }

  static Future<String> exportDay() async {
    var now = DateTime.now();
    String reportDate = DateFormat('dd-MM-yyyy hh_mm_a').format(now);

    var excel = Excel.createExcel();
    var records = DayRecordsStore.getAll();

    excel.delete('Sheet1');

    // =========================
    // المبيعات
    // =========================
    var salesSheet = excel['المبيعات'];
    var salesRecords = records.where((e) => e['type'] == 'sale').toList();
    final salesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in salesRecords) {
      final key = record['invoiceId'] ?? record['time'] ?? record['date'];
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
        salesSheet.appendRow([]);
        salesSheet.appendRow([]);
      }

      final invoiceId = invoiceNum.toString();

      salesSheet.appendRow(['Invoice ID', invoiceId]);
      salesSheet.appendRow([
        'Date',
        first['time'] != null && (first['time'] as String).isNotEmpty
            ? DateFormat('dd-MM-yyyy hh:mm a')
                .format(DateTime.parse(first['time']))
            : reportDate
      ]);
      salesSheet.appendRow(['Customer Name', first['customer']]);
      salesSheet.appendRow(['Payment Type', first['paymentType']]);
      salesSheet.appendRow(['Discount', first['discount'] ?? 0]);
      salesSheet.appendRow(['Paid Amount', first['paidAmount']]);
      salesSheet.appendRow(['Cashbox', first['wallet']]);
      salesSheet.appendRow(['Remaining', first['dueAmount']]);
      salesSheet.appendRow(['Invoice Total', first['invoiceTotal']]);

      salesSheet.appendRow([]);
      salesSheet.appendRow(['item_name', 'qty', 'unit_price', 'total']);

      for (var item in invoiceItems) {
        salesSheet
            .appendRow([item['item'], item['qty'], item['price'], item['total']]);
      }
      invoiceNum++;
    }

    // =========================
    // المشتريات
    // =========================
    var purchasesSheet = excel['المشتريات'];
    var purchaseRecords =
        records.where((e) => e['type'] == 'purchase').toList();
    final purchasesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in purchaseRecords) {
      final key = record['invoiceId'] ?? record['time'] ?? record['date'];
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
        purchasesSheet.appendRow([]);
        purchasesSheet.appendRow([]);
      }

      final invoiceId = invoiceNumPurchase.toString();

      purchasesSheet.appendRow(['Invoice ID', invoiceId]);
      purchasesSheet.appendRow([
        'Date',
        first['time'] != null && (first['time'] as String).isNotEmpty
            ? DateFormat('dd-MM-yyyy hh:mm a')
                .format(DateTime.parse(first['time']))
            : reportDate
      ]);
      purchasesSheet.appendRow(['Supplier Name', first['supplier']]);
      purchasesSheet.appendRow(['Payment Type', first['paymentType']]);
      purchasesSheet.appendRow(['Discount', first['discount'] ?? 0]);
      purchasesSheet.appendRow(['Paid Amount', first['paidAmount']]);
      purchasesSheet.appendRow(['Cashbox', first['wallet']]);
      purchasesSheet.appendRow(['Remaining', first['dueAmount']]);
      purchasesSheet.appendRow(['Invoice Total', first['invoiceTotal']]);

      purchasesSheet.appendRow([]);
      purchasesSheet.appendRow(['item_name', 'qty', 'unit_price', 'total']);

      for (var item in invoiceItems) {
        purchasesSheet.appendRow(
            [item['item'], item['qty'], item['price'], item['total']]);
      }
      invoiceNumPurchase++;
    }

    // =========================
    // المشتريات اوتو
    // =========================
    var purchasesAutoSheet = excel['المشتريات اوتو'];
    purchasesAutoSheet.appendRow([
      'رقم الفاتورة',
      'اسم المورد',
      'التاريخ',
      'اسم الصنف',
      'الكميه',
      'السعر',
      'المدفوع',
      'الخزينه',
      'الخصم'
    ]);

    var invoiceNumPurchaseAuto = 1;
    for (final invoiceItems in purchasesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;

      final formattedDate = first['time'] != null && (first['time'] as String).isNotEmpty
          ? DateFormat('d/M/y').format(DateTime.parse(first['time']))
          : DateFormat('d/M/y').format(now);

      for (var item in invoiceItems) {
        purchasesAutoSheet.appendRow([
          'فاتورة رقم: $invoiceNumPurchaseAuto',
          first['supplier'],
          formattedDate,
          item['item'],
          item['qty'],
          item['price'],
          null,
          null,
          null
        ]);
      }
      purchasesAutoSheet.appendRow([
        'فاتورة رقم: $invoiceNumPurchaseAuto',
        null,
        null,
        null,
        null,
        null,
        first['paidAmount'],
        first['wallet'],
        first['discount'] ?? 0
      ]);

      invoiceNumPurchaseAuto++;
    }
    
    // =========================
    // المبيعات اوتو
    // =========================
    var salesAutoSheet = excel['المبيعات اوتو'];
    salesAutoSheet.appendRow([
      'رقم الفاتورة',
      'اسم العميل',
      'التاريخ',
      'اسم الصنف',
      'الكميه',
      'السعر',
      'المدفوع',
      'الخزينه',
      'الخصم'
    ]);

    var invoiceNumSaleAuto = 1;
    for (final invoiceItems in salesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;

      final formattedDate = first['time'] != null && (first['time'] as String).isNotEmpty
          ? DateFormat('d/M/y').format(DateTime.parse(first['time']))
          : DateFormat('d/M/y').format(now);

      for (var item in invoiceItems) {
        salesAutoSheet.appendRow([
          'فاتورة رقم: $invoiceNumSaleAuto',
          first['customer'],
          formattedDate,
          item['item'],
          item['qty'],
          item['price'],
          null,
          null,
          null
        ]);
      }
      salesAutoSheet.appendRow([
        'فاتورة رقم: $invoiceNumSaleAuto',
        null,
        null,
        null,
        null,
        null,
        first['paidAmount'],
        first['wallet'],
        first['discount'] ?? 0
      ]);

      invoiceNumSaleAuto++;
    }

    // مصروفات الشغل
    var expenses = excel['مصروفات الشغل'];
    expenses.appendRow(['المبلغ', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'expense')) {
      expenses.appendRow([r['amount'], r['description'], r['wallet']]);
    }

    // مسحوبات شخصية
    var withdraws = excel['مسحوبات شخصية'];
    withdraws.appendRow(['المبلغ', 'اسم الشخص', 'البيان']);
    for (var r in records.where((e) => e['type'] == 'withdraw')) {
      withdraws.appendRow([r['amount'], r['person'], r['description']]);
    }

    // التحويلات
    var transfers = excel['التحويلات'];
    transfers.appendRow(['من', 'إلى', 'المبلغ']);
    for (var r in records.where((e) => e['type'] == 'transfer')) {
      transfers.appendRow([r['from'], r['to'], r['amount']]);
    }

    // سداد العملاء
    var settlement = excel['سداد العملاء'];
    settlement.appendRow(['العميل', 'المبلغ', 'طريقة الدفع', 'المحفظة']);
    for (var r in records.where((e) => e['type'] == 'settlement')) {
      settlement.appendRow([r['customer'], r['amount'], r['paymentType'], r['wallet']]);
    }

    // سداد الموردين
    var supplierSettlement = excel['سداد الموردين'];
    supplierSettlement.appendRow(['المورد', 'المبلغ', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'supplier_settlement')) {
      supplierSettlement.appendRow([r['supplier'], r['amount'], r['wallet']]);
    }

    // ملخص اليوم
    var summarySheet = excel['ملخص اليوم'];
    final startOfDayCash = CashState.instance.startOfDayCash;
    final startOfDayWallets = CashState.instance.startOfDayWallets;
    final totalStartOfDayMoney = startOfDayCash +
        startOfDayWallets.values.fold(0.0, (sum, val) => sum + val);

    final totalSales = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['invoiceTotal'] as double));
    final totalPaidSales = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as double));
    final totalSalesDiscount = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['discount'] as double? ?? 0.0));
    final subtotalSales = totalSales + totalSalesDiscount;
    final totalDueSales = subtotalSales - totalPaidSales - totalSalesDiscount;

    final totalPurchases = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['invoiceTotal'] as double));
    final totalPaidPurchases = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as double));
    final totalPurchasesDiscount = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['discount'] as double? ?? 0.0));
    final subtotalPurchases = totalPurchases + totalPurchasesDiscount;
    final totalDuePurchases = subtotalPurchases - totalPaidPurchases - totalPurchasesDiscount;

    summarySheet.appendRow(['رصيد بداية اليوم']);
    summarySheet.appendRow(['اجمالي', totalStartOfDayMoney]);
    summarySheet.appendRow(['نقدي', startOfDayCash]);
    for (var entry in startOfDayWallets.entries) {
      summarySheet.appendRow([entry.key, entry.value]);
    }
    summarySheet.appendRow([]);
    summarySheet.appendRow(['المشتريات']);
    summarySheet.appendRow(['اجمالي فواتير المشتريات', subtotalPurchases]);
    summarySheet.appendRow(['اجمالي الخصومات', totalPurchasesDiscount]);
    summarySheet.appendRow(['صافي المشتريات', totalPurchases]);
    summarySheet.appendRow(['اجمالي المدفوع', totalPaidPurchases]);
    summarySheet.appendRow(['اجمالي المتبقي', totalDuePurchases]);
    summarySheet.appendRow([]);
    summarySheet.appendRow(['المبيعات']);
    summarySheet.appendRow(['اجمالي فواتير المبيعات', subtotalSales]);
    summarySheet.appendRow(['اجمالي الخصومات', totalSalesDiscount]);
    summarySheet.appendRow(['صافي المبيعات', totalSales]);
    summarySheet.appendRow(['اجمالي المستلم', totalPaidSales]);
    summarySheet.appendRow(['اجمالي المتبقي', totalDueSales]);
    summarySheet.appendRow([]);
    summarySheet.appendRow(['رصيد نهاية اليوم']);
    summarySheet.appendRow(['اجمالي', CashState.instance.totalMoney]);
    summarySheet.appendRow(['نقدي', CashState.instance.cash]);
    for (var entry in CashState.instance.wallets.entries) {
      summarySheet.appendRow([entry.key, entry.value]);
    }

    if (await Permission.manageExternalStorage.request().isGranted) {
      String downloadsPath = '/storage/emulated/0/Download';
      final reportDir = Directory(downloadsPath + "/التقرير اليومي");
      if (!await reportDir.exists()) {
        await reportDir.create(recursive: true);
      }
      final filePath = "${reportDir.path}/تقرير يوم $reportDate.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!, flush: true);
      return filePath;
    }
    return "";
  }
}
