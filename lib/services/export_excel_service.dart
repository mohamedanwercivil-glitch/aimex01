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
    final dayStartTime = DayState.instance.dayStartTime ?? DateTime.now();
    final reportDate = DateFormat('dd-MM-yyyy').format(dayStartTime);
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
      final customer = first['customer'] ?? 'عميل';
      final invoiceTime = first['time'] != null ? DateTime.parse(first['time']) : DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(invoiceTime);

      final saleItems = items.map((e) => SaleItem(
        name: e['item'],
        qty: (e['qty'] as num).toDouble(),
        price: (e['price'] as num).toDouble(),
        isReturn: e['isReturn'] ?? false,
      )).toList();

      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = records
          .where((r) => r['invoiceId'] == invoiceId && r['type'] == 'settlement')
          .fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());

      final pdfData = await PdfService.generateInvoice(
        customerName: customer,
        items: saleItems,
        subtotal: (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble(),
        discount: (first['discount'] as num).toDouble(),
        total: (first['invoiceTotal'] as num).toDouble(),
        paidAmount: primaryPaid + secondaryPaid,
        dueAmount: (first['invoiceTotal'] as num).toDouble() - (primaryPaid + secondaryPaid),
        invoiceId: first['invoiceNumber']?.toString() ?? '0',
        previousBalance: 0,
        newBalance: 0, 
      );

      // 🔥 تغيير اسم الملف ليكون: اسم العميل تاريخ اليوم
      final file = File('${pdfDir.path}/${customer}_$dateStr.pdf');
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
    final dayStartTime = DayState.instance.dayStartTime ?? DateTime.now();
    String reportDate = DateFormat('dd-MM-yyyy').format(dayStartTime);
    var excel = Excel.createExcel();
    var records = DayRecordsStore.getAll();
    excel.delete('Sheet1');

    double getSecondaryAmount(String? invoiceId, String type) {
      if (invoiceId == null) return 0.0;
      return records
          .where((r) => r['invoiceId'] == invoiceId && r['type'] == type)
          .fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
    }

    // --- 1. الأصناف الجديدة ---
    var newItemsSheet = excel['الأصناف الجديدة'];
    newItemsSheet.appendRow(['اسم الصنف']);
    var newItems = InventoryStore.getNewItemsToday(dayStartTime);
    for (var item in newItems) {
      newItemsSheet.appendRow([item['name']]);
    }

    // --- 2. الموردين الجدد ---
    var newSuppliersSheet = excel['الموردين الجدد'];
    newSuppliersSheet.appendRow(['اسم المورد']);
    var newSuppliers = SupplierStore.getNewSuppliersToday(dayStartTime);
    for (var name in newSuppliers) {
      newSuppliersSheet.appendRow([name]);
    }

    // --- 3. التحويلات ---
    var transfersSheet = excel['التحويلات'];
    transfersSheet.appendRow(['من محفظة', 'إلى محفظة', 'المبلغ', 'مصاريف التحويل', 'الوقت']);
    for (var r in records.where((e) => e['type'] == 'transfer')) {
      transfersSheet.appendRow([
        r['from'] ?? 'نقدي',
        r['to'] ?? 'نقدي',
        r['amount'],
        r['fee'] ?? 0,
        r['time']?.toString().split('T')[1].split('.')[0] ?? ''
      ]);
    }

    // --- 4. سداد الموردين ---
    var supplierSettlement = excel['سداد الموردين'];
    supplierSettlement.appendRow(['المورد', 'المبلغ', 'الخزنة', 'ملاحظات']);
    for (var r in records.where((e) => e['type'] == 'supplier_settlement')) {
      bool skip = false;
      if (r['invoiceId'] != null) {
        final purRecordsForThis = records.where((e) => e['type'] == 'purchase' && e['invoiceId'] == r['invoiceId']);
        if (purRecordsForThis.isNotEmpty) {
          final pAmt = (purRecordsForThis.first['paidAmount'] as num).toDouble();
          if (pAmt == 0) skip = true; 
        }
      }
      if (!skip) supplierSettlement.appendRow([r['supplier'], r['amount'], r['wallet'], r['remarks'] ?? '']);
    }

    // --- 5. المشتريات أوتو ---
    var purchaseAutoSheet = excel['المشتريات أوتو'];
    purchaseAutoSheet.appendRow(['اسم مورد', 'اسم الصنف', 'الكميه', 'سعر الوحده', 'الخزنه', 'المدفوع', 'الخصم']);
    var purchaseRecords = records.where((e) => e['type'] == 'purchase').toList();
    final purchasesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in purchaseRecords) {
      final key = record['invoiceId'];
      if (!purchasesByInvoice.containsKey(key)) purchasesByInvoice[key] = [];
      purchasesByInvoice[key]!.add(record);
    }
    for (final invoiceItems in purchasesByInvoice.values) {
      final nonReturnItems = invoiceItems.where((item) => item['isReturn'] != true).toList();
      if (nonReturnItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      for (var item in nonReturnItems) {
        purchaseAutoSheet.appendRow([item['supplier'], item['item'], item['qty'], item['price'], '', '', '']);
      }
      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = getSecondaryAmount(invoiceId, 'supplier_settlement');
      double displayPaid;
      String displayWallet = "";
      if (primaryPaid > 0 && secondaryPaid > 0) {
        displayPaid = primaryPaid;
        displayWallet = (first['paymentType'] == 'كاش') ? 'نقدي' : (first['wallet'] ?? '');
      } else if (secondaryPaid > 0) {
        displayPaid = secondaryPaid;
        final secRecord = records.firstWhere((r) => r['invoiceId'] == invoiceId && r['type'] == 'supplier_settlement');
        displayWallet = secRecord['wallet'] ?? 'نقدي';
      } else {
        displayPaid = primaryPaid;
        String rawPT = first['paymentType'] ?? 'كاش';
        displayWallet = rawPT == 'آجل' ? 'آجل' : (rawPT == 'كاش' ? 'نقدي' : (first['wallet'] ?? ''));
      }
      purchaseAutoSheet.appendRow(['', '', '', '', displayWallet, displayPaid, first['discount'] ?? 0]);
    }

    // --- 6. المشتريات (التفصيلي) ---
    var purchasesSheet = excel['المشتريات'];
    for (final invoiceItems in purchasesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = getSecondaryAmount(invoiceId, 'supplier_settlement');
      final totalPaid = primaryPaid + secondaryPaid;

      purchasesSheet.appendRow(['رقم الفاتورة', first['invoiceNumber']]);
      purchasesSheet.appendRow(['التاريخ', first['time']?.toString().split('T')[0] ?? '']);
      purchasesSheet.appendRow(['إسم المورد', first['supplier']]);
      purchasesSheet.appendRow(['إجمالي الفاتورة', (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble()]);
      
      if (primaryPaid > 0 || (primaryPaid == 0 && secondaryPaid == 0)) {
        String ptLabel = (primaryPaid > 0 && secondaryPaid > 0) ? 'طريقه دفع 1' : 'طريقة الدفع';
        purchasesSheet.appendRow([ptLabel, first['paymentType'] ?? 'كاش']);
        purchasesSheet.appendRow(['الخزنة', first['wallet'] ?? 'نقدي']);
        purchasesSheet.appendRow(['المبلغ المدفوع', primaryPaid]);
      }
      if (secondaryPaid > 0) {
        final secRecord = records.firstWhere((r) => r['invoiceId'] == invoiceId && r['type'] == 'supplier_settlement');
        purchasesSheet.appendRow(['طريقة دفع 2', 'تحويل/سداد']);
        purchasesSheet.appendRow(['الخزنة 2', secRecord['wallet'] ?? 'نقدي']);
        purchasesSheet.appendRow(['المبلغ المدفوع 2', secondaryPaid]);
      }
      purchasesSheet.appendRow(['إجمالي المدفوع', totalPaid]);
      purchasesSheet.appendRow(['الخصم', first['discount'] ?? 0]);
      purchasesSheet.appendRow([]);
      purchasesSheet.appendRow(['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي', 'الحالة']);
      for (var item in invoiceItems) {
        purchasesSheet.appendRow([item['item'], item['qty'], item['price'], item['total'], item['isReturn'] == true ? 'مرتجع للمورد' : 'شراء']);
      }
      purchasesSheet.appendRow([]);
    }

    // --- 7. العملاء الجدد ---
    var newCustomersSheet = excel['العملاء الجدد'];
    newCustomersSheet.appendRow(['اسم العميل']);
    var newCustomers = CustomerStore.getNewCustomersToday(dayStartTime);
    for (var name in newCustomers) {
      newCustomersSheet.appendRow([name]);
    }

    // --- 8. سداد العملاء ---
    var settlement = excel['سداد العملاء'];
    settlement.appendRow(['العميل', 'المبلغ', 'المحفظة', 'ملاحظات']);
    for (var r in records.where((e) => e['type'] == 'settlement')) {
      bool skip = false;
      if (r['invoiceId'] != null) {
        final saleRecordsForThis = records.where((e) => e['type'] == 'sale' && e['invoiceId'] == r['invoiceId']);
        if (saleRecordsForThis.isNotEmpty) {
          final pAmt = (saleRecordsForThis.first['paidAmount'] as num).toDouble();
          if (pAmt == 0) skip = true;
        }
      }
      if (!skip) settlement.appendRow([r['customer'], r['amount'], r['wallet'], r['remarks'] ?? '']);
    }

    // --- 9. المبيعات (التفصيلي) ---
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
      final invoiceId = first['invoiceId'];
      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = getSecondaryAmount(invoiceId, 'settlement');
      final totalPaid = primaryPaid + secondaryPaid;

      salesSheet.appendRow(['رقم الفاتورة', first['invoiceNumber']]);
      salesSheet.appendRow(['التاريخ', first['time']?.toString().split('T')[0] ?? '']);
      salesSheet.appendRow(['إسم العميل', first['customer']]);
      salesSheet.appendRow(['إجمالي الفاتورة', (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble()]);
      
      if (primaryPaid > 0 || (primaryPaid == 0 && secondaryPaid == 0)) {
        String ptLabel = (primaryPaid > 0 && secondaryPaid > 0) ? 'طريقه دفع 1' : 'طريقة الدفع';
        salesSheet.appendRow([ptLabel, first['paymentType'] ?? 'كاش']);
        salesSheet.appendRow(['الخزنة', first['wallet'] ?? 'نقدي']);
        salesSheet.appendRow(['المبلغ المدفوع', primaryPaid]);
      }
      if (secondaryPaid > 0) {
        final secRecord = records.firstWhere((r) => r['invoiceId'] == invoiceId && r['type'] == 'settlement');
        salesSheet.appendRow(['طريقة دفع 2', 'تحويل/سداد']);
        salesSheet.appendRow(['الخزنة 2', secRecord['wallet'] ?? 'نقدي']);
        salesSheet.appendRow(['المبلغ المدفوع 2', secondaryPaid]);
      }
      salesSheet.appendRow(['إجمالي المدفوع', totalPaid]);
      salesSheet.appendRow(['الخصم', first['discount'] ?? 0]);
      salesSheet.appendRow([]);
      salesSheet.appendRow(['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي', 'الحالة']);
      for (var item in invoiceItems) {
        salesSheet.appendRow([item['item'], item['qty'], item['price'], item['total'], item['isReturn'] == true ? 'مرتجع' : 'بيع']);
      }
      salesSheet.appendRow([]);
    }

    // --- 10. المبيعات أوتو ---
    var salesAutoSheet = excel['المبيعات أوتو'];
    salesAutoSheet.appendRow(['اسم عميل', 'اسم الصنف', 'الكميه', 'سعر الوحده', 'الخزنه', 'المدفوع', 'الخصم']);
    for (final invoiceItems in salesByInvoice.values) {
      final nonReturnItems = invoiceItems.where((item) => item['isReturn'] != true).toList();
      if (nonReturnItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      for (var item in nonReturnItems) {
        salesAutoSheet.appendRow([item['customer'], item['item'], item['qty'], item['price'], '', '', '']);
      }
      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = getSecondaryAmount(invoiceId, 'settlement');
      double displayPaid;
      String displayWallet = "";
      if (primaryPaid > 0 && secondaryPaid > 0) {
        displayPaid = primaryPaid;
        displayWallet = (first['paymentType'] == 'كاش') ? 'نقدي' : (first['wallet'] ?? '');
      } else if (secondaryPaid > 0) {
        displayPaid = secondaryPaid;
        final secRecord = records.firstWhere((r) => r['invoiceId'] == invoiceId && r['type'] == 'settlement');
        displayWallet = secRecord['wallet'] ?? 'نقدي';
      } else {
        displayPaid = primaryPaid;
        String rawPT = first['paymentType'] ?? 'كاش';
        displayWallet = rawPT == 'آجل' ? 'آجل' : (rawPT == 'كاش' ? 'نقدي' : (first['wallet'] ?? ''));
      }
      salesAutoSheet.appendRow(['', '', '', '', displayWallet, displayPaid, first['discount'] ?? 0]);
    }

    // --- 11. المرتجعات ---
    var returnsSheet = excel['المرتجعات'];
    returnsSheet.appendRow(['المورد/العميل', 'الصنف', 'الكمية', 'السعر', 'الإجمالي', 'النوع']);
    for (var r in records.where((e) => (e['type'] == 'purchase' || e['type'] == 'sale' || e['type'] == 'sales_return') && e['isReturn'] == true)) {
      returnsSheet.appendRow([r['supplier'] ?? r['customer'], r['item'], r['qty'], r['price'], r['total'], r['type'] == 'purchase' ? 'مرتجع شراء' : 'مرتجع بيع']);
    }

    // --- 12. المسحوبات الشخصية ---
    var withdrawSheet = excel['المسحوبات الشخصية'];
    withdrawSheet.appendRow(['المبلغ', 'الشخص', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'withdraw')) {
      withdrawSheet.appendRow([r['amount'], r['person'] ?? '', r['description'] ?? r['reason'] ?? '', r['source'] ?? r['wallet'] ?? 'نقدي']);
    }

    // --- 13. مصروفات الشغل ---
    var expenses = excel['مصروفات الشغل'];
    expenses.appendRow(['المبلغ', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'expense')) {
      expenses.appendRow([r['amount'], r['description'], r['wallet']]);
    }

    // --- 14. ملخص اليوم ---
    var summarySheet = excel['ملخص اليوم'];
    final ds = DayState.instance;
    summarySheet.appendRow(['البيان', 'القيمة']);
    summarySheet.appendRow(['إجمالي المبيعات (صافي)', ds.totalSales]);
    summarySheet.appendRow(['خصومات المبيعات', ds.totalSalesDiscount]);
    summarySheet.appendRow(['إجمالي المشتريات (بضاعة)', ds.totalPurchases]);
    summarySheet.appendRow(['خصومات المشتريات', ds.totalPurchaseDiscount]);
    summarySheet.appendRow(['إجمالي المصروفات', ds.totalExpenses]);
    summarySheet.appendRow(['صافي ربح اليوم (تقديري)', ds.netProfit]);

    final fileBytes = excel.encode();
    final fileName = "تقرير_يومي_$reportDate.xlsx";
    final file = File("$targetDirPath/$fileName");
    await file.writeAsBytes(fileBytes!);
    return file.path;
  }
}
