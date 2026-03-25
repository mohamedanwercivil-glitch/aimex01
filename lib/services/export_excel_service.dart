import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../data/day_records_store.dart';
import '../data/inventory_store.dart';
import '../data/customer_store.dart';
import '../data/supplier_store.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../models/sale_item.dart';
import 'pdf_service.dart';

class ExportExcelService {
  static Future<Map<String, String>> exportDayWithInvoices() async {
    final tempDir = await getTemporaryDirectory();
    final excelPath = await exportDay(tempDir.path);
    final zipPath = await generateAllInvoicesZip();
    
    return {
      'excel': excelPath,
      'zip': zipPath,
    };
  }

  static Future<String> generateAllInvoicesZip() async {
    final now = DateTime.now();
    final reportDate = DateFormat('dd-MM-yyyy').format(now);
    final tempDir = await getTemporaryDirectory();
    final targetPath = tempDir.path;
    final pdfDir = Directory('${tempDir.path}/daily_sales_pdfs');

    if (await pdfDir.exists()) await pdfDir.delete(recursive: true);
    await pdfDir.create();

    var records = DayRecordsStore.getAll();
    var salesRecords = records.where((e) => e['type'] == 'sale').toList();
    final salesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in salesRecords) {
      final key = record['invoiceId'];
      if (!salesByInvoice.containsKey(key)) salesByInvoice[key] = [];
      salesByInvoice[key]!.add(record);
    }

    if (salesByInvoice.isEmpty) return "";

    for (final invoiceId in salesByInvoice.keys) {
      final items = salesByInvoice[invoiceId]!;
      final first = items.first;
      final invoiceNum = first['invoiceNumber'] ?? '0';
      final customer = first['customer'] ?? 'عميل';

      final saleItems = items.map((e) => SaleItem(
        name: e['item'],
        qty: (e['qty'] as num).toDouble(),
        price: (e['price'] as num).toDouble(),
        isReturn: e['isReturn'] ?? false,
      )).toList();

      final pdfData = await PdfService.generateInvoice(
        customerName: customer,
        items: saleItems,
        subtotal: (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble(),
        discount: (first['discount'] as num).toDouble(),
        total: (first['invoiceTotal'] as num).toDouble(),
        paidAmount: (first['paidAmount'] as num).toDouble(),
        dueAmount: (first['dueAmount'] as num).toDouble(),
        invoiceId: invoiceNum.toString(),
        previousBalance: 0,
        newBalance: 0, 
      );

      final file = File('${pdfDir.path}/فاتورة_بيع_$invoiceNum.pdf');
      await file.writeAsBytes(pdfData);
    }

    final encoder = ZipFileEncoder();
    String zipName = "فواتير_مبيعات_$reportDate.zip";
    String zipPath = "$targetPath/$zipName";
    encoder.create(zipPath);
    await encoder.addDirectory(pdfDir);
    encoder.close();

    return zipPath;
  }

  static Future<void> clearDailyInvoices() async {
    final tempDir = await getTemporaryDirectory();
    final pdfDir = Directory('${tempDir.path}/daily_sales_pdfs');
    if (await pdfDir.exists()) await pdfDir.delete(recursive: true);
  }

  static Future<String> exportDay(String targetDirPath) async {
    var now = DateTime.now();
    String reportDate = DateFormat('dd-MM-yyyy hh_mm_a').format(now);
    var excel = Excel.createExcel();
    var records = DayRecordsStore.getAll();
    final dayStartTime = DayState.instance.dayStartTime;
    excel.delete('Sheet1');

    // 1. الأصناف الجديدة
    var newItemsSheet = excel['الأصناف الجديدة'];
    newItemsSheet.appendRow(['اسم الصنف']);
    var newItems = InventoryStore.getNewItemsToday(dayStartTime);
    for (var item in newItems) {
      newItemsSheet.appendRow([item['name']]);
    }

    // 2. العملاء الجدد
    var newCustomersSheet = excel['العملاء الجدد'];
    newCustomersSheet.appendRow(['اسم العميل']);
    var newCustomers = CustomerStore.getNewCustomersToday(dayStartTime);
    for (var name in newCustomers) {
      newCustomersSheet.appendRow([name]);
    }

    // 3. الموردين الجدد
    var newSuppliersSheet = excel['الموردين الجدد'];
    newSuppliersSheet.appendRow(['اسم المورد']);
    var newSuppliers = SupplierStore.getNewSuppliersToday(dayStartTime);
    for (var name in newSuppliers) {
      newSuppliersSheet.appendRow([name]);
    }

    // 4. المشتريات (الشيت التفصيلي)
    var purchasesSheet = excel['المشتريات'];
    var purchaseRecords = records.where((e) => e['type'] == 'purchase').toList();
    final purchasesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in purchaseRecords) {
      final key = record['invoiceId'];
      if (!purchasesByInvoice.containsKey(key)) purchasesByInvoice[key] = [];
      purchasesByInvoice[key]!.add(record);
    }
    for (final invoiceItems in purchasesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      String rawPaymentType = first['paymentType'] ?? 'كاش';
      String walletVal = rawPaymentType == 'كاش' ? 'كاش' : (rawPaymentType == 'تحويل' ? (first['wallet'] ?? '') : '');
      purchasesSheet.appendRow(['رقم الفاتورة', first['invoiceNumber']]);
      purchasesSheet.appendRow(['التاريخ', first['time']?.toString().split(' ')[0] ?? '']);
      purchasesSheet.appendRow(['إسم المورد', first['supplier']]);
      purchasesSheet.appendRow(['إجمالي الفاتورة', (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble()]);
      purchasesSheet.appendRow(['طريقة الدفع', rawPaymentType == 'كاش' ? 'نقدي' : rawPaymentType]);
      purchasesSheet.appendRow(['الخزنة', walletVal]);
      purchasesSheet.appendRow(['الخصم', first['discount'] ?? 0]);
      purchasesSheet.appendRow(['المبلغ المدفوع فعلياً', first['paidAmount']]);
      purchasesSheet.appendRow([]);
      purchasesSheet.appendRow(['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي', 'الحالة']);
      for (var item in invoiceItems) {
        purchasesSheet.appendRow([item['item'], item['qty'], item['price'], item['total'], item['isReturn'] == true ? 'مرتجع للمورد' : 'شراء']);
      }
      purchasesSheet.appendRow([]);
    }

    // 5. المبيعات (الشيت التفصيلي)
    var salesSheet = excel['المبيعات'];
    var salesRecords = records.where((e) => e['type'] == 'sale').toList();
    final salesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in salesRecords) {
      final key = record['invoiceId'];
      if (!salesByInvoice.containsKey(key)) salesByInvoice[key] = [];
      salesByInvoice[key]!.add(record);
    }
    for (final invoiceItems in salesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      String rawPaymentType = first['paymentType'] ?? 'كاش';
      String walletVal = rawPaymentType == 'كاش' ? 'كاش' : (rawPaymentType == 'تحويل' ? (first['wallet'] ?? '') : '');
      salesSheet.appendRow(['رقم الفاتورة', first['invoiceNumber']]);
      salesSheet.appendRow(['التاريخ', first['time']?.toString().split(' ')[0] ?? '']);
      salesSheet.appendRow(['إسم العميل', first['customer']]);
      salesSheet.appendRow(['إجمالي الفاتورة', (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble()]);
      salesSheet.appendRow(['طريقة الدفع', rawPaymentType == 'كاش' ? 'نقدي' : rawPaymentType]);
      salesSheet.appendRow(['الخزنة', walletVal]);
      salesSheet.appendRow(['الخصم', first['discount'] ?? 0]);
      salesSheet.appendRow(['المبلغ المدفوع فعلياً', first['paidAmount']]);
      salesSheet.appendRow([]);
      salesSheet.appendRow(['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي', 'الحالة']);
      for (var item in invoiceItems) {
        salesSheet.appendRow([item['item'], item['qty'], item['price'], item['total'], item['isReturn'] == true ? 'مرتجع' : 'بيع']);
      }
      salesSheet.appendRow([]);
    }

    // 6. سداد العملاء
    var settlement = excel['سداد العملاء'];
    settlement.appendRow(['العميل', 'المبلغ', 'المحفظة']);
    for (var r in records.where((e) => e['type'] == 'settlement')) {
      settlement.appendRow([r['customer'], r['amount'], r['wallet']]);
    }

    // 7. سداد الموردين
    var supplierSettlement = excel['سداد الموردين'];
    supplierSettlement.appendRow(['المورد', 'المبلغ', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'supplier_settlement')) {
      supplierSettlement.appendRow([r['supplier'], r['amount'], r['wallet']]);
    }

    // 8. المسحوبات الشخصية
    var withdrawSheet = excel['المسحوبات الشخصية'];
    withdrawSheet.appendRow(['المبلغ', 'الشخص', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'withdraw')) {
      withdrawSheet.appendRow([r['amount'], r['person'] ?? '', r['description'] ?? r['reason'] ?? '', r['source'] ?? r['wallet'] ?? 'نقدي']);
    }

    // 9. مصروفات الشغل
    var expenses = excel['مصروفات الشغل'];
    expenses.appendRow(['المبلغ', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'expense')) {
      expenses.appendRow([r['amount'], r['description'], r['wallet']]);
    }

    // 🔥 شيت المرتجعات
    var returnsSheet = excel['المرتجعات'];
    returnsSheet.appendRow(['المورد/العميل', 'الصنف', 'الكمية', 'السعر', 'الإجمالي', 'النوع']);
    for (var r in records.where((e) => (e['type'] == 'purchase' || e['type'] == 'sale' || e['type'] == 'sales_return') && e['isReturn'] == true)) {
      returnsSheet.appendRow([r['supplier'] ?? r['customer'], r['item'], r['qty'], r['price'], r['total'], r['type'] == 'purchase' ? 'مرتجع شراء' : 'مرتجع بيع']);
    }

    // 🔥 شيت المشتريات أوتو (المطابق للصورة تماماً)
    var purchaseAutoSheet = excel['المشتريات أوتو'];
    purchaseAutoSheet.appendRow(['اسم مورد', 'اسم الصنف', 'الكميه', 'سعر الوحده', 'الخزنه', 'المدفوع', 'الخصم']);
    for (final invoiceItems in purchasesByInvoice.values) {
      final nonReturnItems = invoiceItems.where((item) => item['isReturn'] != true).toList();
      if (nonReturnItems.isEmpty) continue;
      final first = invoiceItems.first;
      String rawPaymentType = first['paymentType'] ?? 'كاش';
      String walletVal = rawPaymentType == 'آجل' ? 'آجل' : (rawPaymentType == 'كاش' ? 'نقدي' : (first['wallet'] ?? ''));
      for (var item in nonReturnItems) {
        purchaseAutoSheet.appendRow([item['supplier'], item['item'], item['qty'], item['price'], '', '', '']);
      }
      double paid = (first['paidAmount'] as num).toDouble();
      double disc = (first['discount'] as num).toDouble();
      if (paid != 0 || disc != 0 || rawPaymentType == 'آجل') {
        purchaseAutoSheet.appendRow(['', '', '', '', walletVal, first['paidAmount'], first['discount'] ?? 0]);
      }
    }

    // 🔥 شيت المبيعات أوتو (المطابق للصورة تماماً)
    var salesAutoSheet = excel['المبيعات أوتو'];
    salesAutoSheet.appendRow(['اسم عميل', 'اسم الصنف', 'الكميه', 'سعر الوحده', 'الخزنه', 'المدفوع', 'الخصم']);
    for (final invoiceItems in salesByInvoice.values) {
      final nonReturnItems = invoiceItems.where((item) => item['isReturn'] != true).toList();
      if (nonReturnItems.isEmpty) continue;
      final first = invoiceItems.first;
      String rawPaymentType = first['paymentType'] ?? 'كاش';
      String walletVal = rawPaymentType == 'آجل' ? 'آجل' : (rawPaymentType == 'كاش' ? 'نقدي' : (first['wallet'] ?? ''));
      for (var item in nonReturnItems) {
        salesAutoSheet.appendRow([item['customer'], item['item'], item['qty'], item['price'], '', '', '']);
      }
      double paid = (first['paidAmount'] as num).toDouble();
      double disc = (first['discount'] as num).toDouble();
      if (paid != 0 || disc != 0 || rawPaymentType == 'آجل') {
        salesAutoSheet.appendRow(['', '', '', '', walletVal, first['paidAmount'], first['discount'] ?? 0]);
      }
    }

    // 🔥 10. ملخص اليوم (مطابق للصورة 100%)
    var summarySheet = excel['ملخص اليوم'];
    summarySheet.appendRow(['البيان', 'التفاصيل', 'المبلغ']);
    
    // --- بداية اليوم ---
    double startTotal = CashState.instance.startOfDayCash + CashState.instance.startOfDayWallets.values.fold(0.0, (a, b) => a + b);
    summarySheet.appendRow(['--- بداية اليوم ---', '', startTotal]);
    summarySheet.appendRow(['', 'نقدي (كاش)', CashState.instance.startOfDayCash]);
    for (var entry in CashState.instance.startOfDayWallets.entries) {
      summarySheet.appendRow(['', entry.key, entry.value]);
    }
    summarySheet.appendRow([]);

    // --- المشتريات ---
    double totalPurNet = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['invoiceTotal'] as num).toDouble());
    double totalPurDiscount = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['discount'] as num).toDouble());
    double totalPurPaid = purchasesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as num).toDouble());
    double totalPurGross = totalPurNet + totalPurDiscount;
    double totalPurDue = totalPurNet - totalPurPaid;
    
    summarySheet.appendRow(['--- المشتريات ---']);
    summarySheet.appendRow(['إجمالي قيمة المشتريات', '', totalPurGross]);
    summarySheet.appendRow(['إجمالي ما تم دفعه', '', totalPurPaid]);
    summarySheet.appendRow(['إجمالي الخصم', '', totalPurDiscount]);
    summarySheet.appendRow(['المتبقي علينا (آجل من مشتريات اليوم)', '', totalPurDue]);
    
    // تفصيل الدفع من الخزائن في المشتريات
    Map<String, double> purPaidByWallet = {'كاش': 0.0};
    for (var w in CashState.instance.wallets.keys) { purPaidByWallet[w] = 0.0; }
    for (var inv in purchasesByInvoice.values) {
      String w = inv.first['wallet'] == 'نقدي' || inv.first['wallet'] == '' ? 'كاش' : inv.first['wallet'];
      purPaidByWallet[w] = (purPaidByWallet[w] ?? 0.0) + (inv.first['paidAmount'] as num).toDouble();
    }
    purPaidByWallet.forEach((name, val) {
      if (val != 0) summarySheet.appendRow(['', 'دفع من $name', val]);
    });
    summarySheet.appendRow([]);

    // --- المبيعات ---
    double totalSaleNet = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['invoiceTotal'] as num).toDouble());
    double totalSaleDiscount = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['discount'] as num).toDouble());
    double totalSalePaid = salesByInvoice.values.fold(0.0, (sum, items) => sum + (items.first['paidAmount'] as num).toDouble());
    double totalSaleGross = totalSaleNet + totalSaleDiscount;
    double totalSaleDue = totalSaleNet - totalSalePaid;

    summarySheet.appendRow(['--- المبيعات ---']);
    summarySheet.appendRow(['إجمالي قيمة المبيعات', '', totalSaleGross]);
    summarySheet.appendRow(['إجمالي ما تم استلامه', '', totalSalePaid]);
    summarySheet.appendRow(['إجمالي الخصم', '', totalSaleDiscount]);
    summarySheet.appendRow(['المتبقي لنا بره (آجل من مبيعات اليوم)', '', totalSaleDue]);
    summarySheet.appendRow([]);

    // --- المصروفات والمسحوبات ---
    double totalExp = records.where((e) => e['type'] == 'expense').fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
    double totalWithdraw = records.where((e) => e['type'] == 'withdraw').fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
    summarySheet.appendRow(['--- المصروفات والمسحوبات ---']);
    summarySheet.appendRow(['إجمالي المصروفات', '', totalExp]);
    summarySheet.appendRow(['إجمالي المسحوبات الشخصية', '', totalWithdraw]);
    summarySheet.appendRow([]);

    // --- تحصيل ودفع مديونيات ---
    double totalSettlement = records.where((e) => e['type'] == 'settlement').fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
    double totalSupplierSettlement = records.where((e) => e['type'] == 'supplier_settlement').fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
    summarySheet.appendRow(['--- تحصيل ودفع مديونيات سابقة ---']);
    summarySheet.appendRow(['إجمالي تحصيل من عملاء (سداد)', '', totalSettlement]);
    summarySheet.appendRow(['إجمالي دفع لموردين (سداد)', '', totalSupplierSettlement]);
    summarySheet.appendRow([]);

    // --- ملخص تغير المديونيات ---
    summarySheet.appendRow(['--- ملخص تغير المديونيات اليوم ---']);
    summarySheet.appendRow(['زيادة ديون الموردين (مشتريات آجل)', '', totalPurDue]);
    summarySheet.appendRow(['نقص ديون الموردين (سداد موردين)', '', totalSupplierSettlement]);
    summarySheet.appendRow(['صافي التغير في حسابات الموردين', '', totalPurDue - totalSupplierSettlement]);
    summarySheet.appendRow(['زيادة ديون العملاء (مبيعات آجل)', '', totalSaleDue]);
    summarySheet.appendRow(['نقص ديون العملاء (سداد عملاء)', '', totalSettlement]);
    summarySheet.appendRow(['صافي التغير في حسابات العملاء', '', totalSaleDue - totalSettlement]);
    summarySheet.appendRow([]);

    // --- نهاية اليوم ---
    double endTotal = CashState.instance.cash + CashState.instance.wallets.values.fold(0.0, (a, b) => a + b);
    summarySheet.appendRow(['--- السيولة المتوفرة نهاية اليوم ---', '', endTotal]);
    summarySheet.appendRow(['', 'نقدي (كاش)', CashState.instance.cash]);
    for (var entry in CashState.instance.wallets.entries) {
      summarySheet.appendRow(['', entry.key, entry.value]);
    }

    final fileBytes = excel.save();
    final file = File('$targetDirPath/تقرير_$reportDate.xlsx');
    await file.writeAsBytes(fileBytes!);
    return file.path;
  }
}
