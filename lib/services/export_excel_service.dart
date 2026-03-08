import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive_io.dart';
import '../data/day_records_store.dart';
import '../data/inventory_store.dart';
import '../data/supplier_store.dart';
import '../data/customer_store.dart';
import '../state/cash_state.dart';
import '../state/day_state.dart';

class ExportExcelService {
  static Future<Map<String, String>> exportDayWithInvoices() async {
    String downloadsPath = '/storage/emulated/0/Download';
    var now = DateTime.now();
    String folderName = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final reportDir = Directory("$downloadsPath/التقرير اليومي/$folderName");
    
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }

    final excelPath = await exportDay(reportDir.path);
    final zipPathPurchase = await zipDailyInvoices(isPurchaseOnly: true);
    await zipDailyInvoices(isPurchaseOnly: false, customPath: reportDir.path);

    return {
      'excel': excelPath,
      'zip': zipPathPurchase, 
    };
  }

  static Future<String> zipDailyInvoices({bool isPurchaseOnly = true, String? customPath}) async {
    var now = DateTime.now();
    String reportDate = DateFormat('dd-MM-yyyy').format(now);
    final appDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${appDir.path}/daily_invoices');
    
    if (!await invoicesDir.exists() || (await invoicesDir.list().isEmpty)) return "";

    final encoder = ZipFileEncoder();
    String fileName = isPurchaseOnly ? "فواتير_الشراء_$reportDate.zip" : "كل_الفواتير_$reportDate.zip";
    String zipPath = customPath != null ? "$customPath/$fileName" : '${appDir.path}/$fileName';
    
    encoder.create(zipPath);
    await for (final file in invoicesDir.list()) {
      if (file is File && file.path.endsWith('.pdf')) {
        if (isPurchaseOnly) {
          if (file.path.contains('فاتورة_شراء')) encoder.addFile(file);
        } else {
          encoder.addFile(file);
        }
      }
    }
    encoder.close();
    return zipPath;
  }

  static Future<void> clearDailyInvoices() async {
    final appDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${appDir.path}/daily_invoices');
    if (await invoicesDir.exists()) await invoicesDir.delete(recursive: true);
  }

  static Future<String> exportDay(String targetDirPath) async {
    var now = DateTime.now();
    String reportDate = DateFormat('dd-MM-yyyy hh_mm_a').format(now);
    var excel = Excel.createExcel();
    var records = DayRecordsStore.getAll();
    final dayStartTime = DayState.instance.dayStartTime;
    excel.delete('Sheet1');

    // =========================
    // المبيعات
    // =========================
    var salesSheet = excel['المبيعات'];
    var salesRecords = records.where((e) => e['type'] == 'sale').toList();
    final salesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in salesRecords) {
      final key = record['invoiceId'];
      if (!salesByInvoice.containsKey(key)) salesByInvoice[key] = [];
      salesByInvoice[key]!.add(record);
    }

    var invoiceNum = 1;
    for (final invoiceItems in salesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      if (invoiceNum > 1) { salesSheet.appendRow([]); salesSheet.appendRow([]); }
      salesSheet.appendRow(['Invoice ID', invoiceNum]);
      salesSheet.appendRow(['Date', first['time']]);
      salesSheet.appendRow(['Customer Name', first['customer']]);
      salesSheet.appendRow(['Paid Amount', first['paidAmount']]);
      salesSheet.appendRow(['Invoice Total', first['invoiceTotal']]);
      salesSheet.appendRow([]);
      salesSheet.appendRow(['item_name', 'qty', 'unit_price', 'total']);
      for (var item in invoiceItems) {
        salesSheet.appendRow([item['item'], item['qty'], item['price'], item['total']]);
      }
      invoiceNum++;
    }

    // =========================
    // المشتريات
    // =========================
    var purchasesSheet = excel['المشتريات'];
    var purchaseRecords = records.where((e) => e['type'] == 'purchase').toList();
    final purchasesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in purchaseRecords) {
      final key = record['invoiceId'];
      if (!purchasesByInvoice.containsKey(key)) purchasesByInvoice[key] = [];
      purchasesByInvoice[key]!.add(record);
    }

    var pInvoiceNum = 1;
    for (final invoiceItems in purchasesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      if (pInvoiceNum > 1) { purchasesSheet.appendRow([]); purchasesSheet.appendRow([]); }
      purchasesSheet.appendRow(['Invoice ID', pInvoiceNum]);
      purchasesSheet.appendRow(['Supplier Name', first['supplier']]);
      purchasesSheet.appendRow(['Paid Amount', first['paidAmount']]);
      purchasesSheet.appendRow(['Invoice Total', first['invoiceTotal']]);
      purchasesSheet.appendRow([]);
      purchasesSheet.appendRow(['item_name', 'qty', 'unit_price', 'total']);
      for (var item in invoiceItems) {
        purchasesSheet.appendRow([item['item'], item['qty'], item['price'], item['total']]);
      }
      pInvoiceNum++;
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

    // سداد العملاء
    var settlement = excel['سداد العملاء'];
    settlement.appendRow(['العميل', 'المبلغ', 'المحفظة']);
    for (var r in records.where((e) => e['type'] == 'settlement')) {
      settlement.appendRow([r['customer'], r['amount'], r['wallet']]);
    }

    // سداد الموردين
    var supplierSettlement = excel['سداد الموردين'];
    supplierSettlement.appendRow(['المورد', 'المبلغ', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'supplier_settlement')) {
      supplierSettlement.appendRow([r['supplier'], r['amount'], r['wallet']]);
    }

    // الجديد
    var newItemsSheet = excel['الأصناف الجديدة'];
    newItemsSheet.appendRow(['اسم الصنف']);
    for (var item in InventoryStore.getNewItemsToday(dayStartTime)) { newItemsSheet.appendRow([item['name']]); }

    // ملخص اليوم (المطور والشامل)
    var summarySheet = excel['ملخص اليوم'];
    
    double totalReceivedFromSales = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as num).toDouble());
    double totalPaidForPurchases = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as num).toDouble());
    double totalCustSettlement = records.where((e) => e['type'] == 'settlement').fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
    double totalSuppSettlement = records.where((e) => e['type'] == 'supplier_settlement').fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
    double totalExp = records.where((e) => e['type'] == 'expense').fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
    double totalWith = records.where((e) => e['type'] == 'withdraw').fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());

    double totalInflow = totalReceivedFromSales + totalCustSettlement;
    double totalOutflow = totalPaidForPurchases + totalSuppSettlement + totalExp + totalWith;

    summarySheet.appendRow(['البيان', 'التفاصيل', 'المبلغ']);
    
    summarySheet.appendRow(['--- أرصدة بداية اليوم (الافتتاحية) ---']);
    double totalStart = CashState.instance.startOfDayCash + CashState.instance.startOfDayWallets.values.fold(0.0, (a, b) => a + b);
    summarySheet.appendRow(['إجمالي رصيد البداية', '', totalStart]);
    summarySheet.appendRow(['', 'نقدي (بداية)', CashState.instance.startOfDayCash]);
    for (var entry in CashState.instance.startOfDayWallets.entries) {
      summarySheet.appendRow(['', '${entry.key} (بداية)', entry.value]);
    }
    
    summarySheet.appendRow([]);
    summarySheet.appendRow(['--- المقبوضات (الداخل للمحل) ---']);
    summarySheet.appendRow(['إجمالي الداخل', '', totalInflow]);
    summarySheet.appendRow(['', 'من عمليات البيع', totalReceivedFromSales]);
    summarySheet.appendRow(['', 'تحصيل مديونيات عملاء', totalCustSettlement]);
    
    summarySheet.appendRow([]);
    summarySheet.appendRow(['--- المدفوعات (الخارج من المحل) ---']);
    summarySheet.appendRow(['إجمالي الخارج', '', totalOutflow]);
    summarySheet.appendRow(['', 'في عمليات الشراء', totalPaidForPurchases]);
    summarySheet.appendRow(['', 'سداد مديونيات موردين', totalSuppSettlement]);
    summarySheet.appendRow(['', 'مصروفات شغل', totalExp]);
    summarySheet.appendRow(['', 'مسحوبات شخصية', totalWith]);
    
    summarySheet.appendRow([]);
    summarySheet.appendRow(['--- صافي الحركة المالية اليومية ---']);
    summarySheet.appendRow(['الصافي (الداخل - الخارج)', '', totalInflow - totalOutflow]);
    
    summarySheet.appendRow([]);
    summarySheet.appendRow(['--- أرصدة نهاية اليوم (الإغلاق) ---']);
    summarySheet.appendRow(['إجمالي رصيد النهاية', '', CashState.instance.totalMoney]);
    summarySheet.appendRow(['', 'نقدي (نهاية)', CashState.instance.cash]);
    for (var entry in CashState.instance.wallets.entries) {
      summarySheet.appendRow(['', '${entry.key} (نهاية)', entry.value]);
    }

    if (await Permission.manageExternalStorage.request().isGranted) {
      final filePath = "$targetDirPath/تقرير يوم $reportDate.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!, flush: true);
      return filePath;
    }
    return "";
  }
}
