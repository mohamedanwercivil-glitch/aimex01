import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/day_records_store.dart';
import '../data/inventory_store.dart';
import '../data/customer_store.dart';
import '../data/supplier_store.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../models/sale_item.dart';
import 'pdf_service.dart';

class ExportExcelService {
  static Future<Directory?> getReportsDirectory() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      if (status.isGranted) {
        final dir = Directory('/storage/emulated/0/aimex/التقرير اليومي');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }
    final docDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${docDir.path}/aimex/التقرير اليومي');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  static Future<Map<String, String>> exportDayWithInvoices() async {
    final reportsDir = await getReportsDirectory();
    final excelPath = await exportDay(reportsDir?.path ?? "");
    final zipPath = await generateAllInvoicesZip(reportsDir?.path ?? "");
    
    return {
      'excel': excelPath,
      'zip': zipPath,
    };
  }

  static String _formatTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dt = DateTime.parse(dateTimeStr.toString());
      return DateFormat('hh:mm:ss a').format(dt);
    } catch (_) {
      String s = dateTimeStr.toString();
      if (s.contains(' ')) {
        final parts = s.split(' ');
        if (parts.length > 1) return parts[1].split('.')[0];
      } else if (s.contains('T')) {
        final parts = s.split('T');
        if (parts.length > 1) return parts[1].split('.')[0];
      }
      return s;
    }
  }

  static String _formatDate(dynamic dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dt = DateTime.parse(dateTimeStr.toString());
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return dateTimeStr.toString().split('T')[0].split(' ')[0];
    }
  }

  static Future<String> generateAllInvoicesZip(String targetDirPath) async {
    if (targetDirPath.isEmpty) return "";
    final dayStartTime = DayState.instance.dayStartTime ?? DateTime.now();
    final reportDate = DateFormat('dd-MM-yyyy').format(dayStartTime);
    final tempDir = await getTemporaryDirectory();
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
        subtotal: (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble() - (first['additionalExpenses'] ?? 0).toDouble(),
        discount: (first['discount'] as num).toDouble(),
        total: (first['invoiceTotal'] as num).toDouble(),
        paidAmount: primaryPaid + secondaryPaid,
        dueAmount: (first['invoiceTotal'] as num).toDouble() - (primaryPaid + secondaryPaid),
        invoiceId: first['invoiceNumber']?.toString() ?? '0',
        previousBalance: 0,
        newBalance: 0, 
      );

      final file = File('${pdfDir.path}/${customer}_$dateStr.pdf');
      await file.writeAsBytes(pdfData);
    }

    final encoder = ZipFileEncoder();
    String zipName = "فواتير_مبيعات_$reportDate.zip";
    String zipPath = "$targetDirPath/$zipName";
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
    if (targetDirPath.isEmpty) return "";
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

    var purchaseRecords = records.where((e) => e['type'] == 'purchase').toList();
    final purchasesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in purchaseRecords) {
      final key = record['invoiceId'];
      if (!purchasesByInvoice.containsKey(key)) purchasesByInvoice[key] = [];
      purchasesByInvoice[key]!.add(record);
    }

    var salesRecords = records.where((e) => e['type'] == 'sale').toList();
    final salesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final record in salesRecords) {
      final key = record['invoiceId'];
      if (!salesByInvoice.containsKey(key)) salesByInvoice[key] = [];
      salesByInvoice[key]!.add(record);
    }

    // --- 1. الأصناف الجديدة ---
    var newItemsSheet = excel['الأصناف الجديدة'];
    newItemsSheet.appendRow(['اسم الصنف']);
    var newItems = InventoryStore.getNewItemsToday(dayStartTime);
    for (var item in newItems) {
      newItemsSheet.appendRow([item['name']]);
    }

    // --- 2. تعديلات المخزن --- (تم النقل لهنا بطلب المستخدم)
    var adjustmentsSheet = excel['تعديلات المخزن'];
    adjustmentsSheet.appendRow(['اسم الصنف', 'الكمية القديمة', 'الكمية الجديدة', 'الفرق', 'السعر القديم', 'السعر الجديد', 'الوقت']);
    for (var r in records.where((e) => e['type'] == 'inventory_adjustment')) {
      final oldQty = (r['oldQty'] as num).toDouble();
      final newQty = (r['newQty'] as num).toDouble();
      adjustmentsSheet.appendRow([
        r['itemName'] ?? '',
        oldQty,
        newQty,
        newQty - oldQty,
        r['oldPrice'] ?? 0,
        r['newPrice'] ?? 0,
        _formatTime(r['date'] ?? r['time'])
      ]);
    }

    // --- 3. الموردين الجدد ---
    var newSuppliersSheet = excel['الموردين الجدد'];
    newSuppliersSheet.appendRow(['اسم المورد']);
    var newSuppliers = SupplierStore.getNewSuppliersToday(dayStartTime);
    for (var name in newSuppliers) {
      newSuppliersSheet.appendRow([name]);
    }

    // --- 4. التحويلات ---
    var transfersSheet = excel['التحويلات'];
    transfersSheet.appendRow(['من محفظة', 'إلى محفظة', 'المبلغ', 'مصاريف التحويل', 'الوقت']);
    for (var r in records.where((e) => e['type'] == 'transfer')) {
      transfersSheet.appendRow([
        r['from'] ?? 'نقدي',
        r['to'] ?? 'نقدي',
        r['amount'],
        r['fee'] ?? 0,
        _formatTime(r['time'])
      ]);
    }

    // --- 5. سداد الموردين ---
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

    // --- 6. المشتريات أوتو ---
    var purchaseAutoSheet = excel['المشتريات أوتو'];
    purchaseAutoSheet.appendRow(['اسم مورد', 'اسم الصنف', 'الكميه', 'سعر الوحده', 'الخزنه', 'المدفوع', 'الخصم', 'مصاريف إضافية']);
    for (final invoiceItems in purchasesByInvoice.values) {
      final nonReturnItems = invoiceItems.where((item) => item['isReturn'] != true).toList();
      if (nonReturnItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      for (var item in nonReturnItems) {
        purchaseAutoSheet.appendRow([item['supplier'], item['item'], item['qty'], item['price'], '', '', '', '']);
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
        String rawPT = first['paymentType'] ?? 'كاش';
        if (rawPT == 'آجل') {
          displayPaid = 0;
          displayWallet = 'نقدي';
        } else {
          displayPaid = primaryPaid;
          displayWallet = (rawPT == 'كاش' ? 'نقدي' : (first['wallet'] ?? ''));
        }
      }
      purchaseAutoSheet.appendRow(['', '', '', '', displayWallet, displayPaid, first['discount'] ?? 0, first['additionalExpenses'] ?? 0]);
    }

    // --- 7. المشتريات (التفصيلي) ---
    var purchasesSheet = excel['المشتريات'];
    for (final invoiceItems in purchasesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = getSecondaryAmount(invoiceId, 'supplier_settlement');
      final totalPaid = primaryPaid + secondaryPaid;

      purchasesSheet.appendRow(['رقم الفاتورة', first['invoiceNumber']]);
      purchasesSheet.appendRow(['التاريخ', _formatDate(first['time'])]);
      purchasesSheet.appendRow(['إسم المورد', first['supplier']]);
      purchasesSheet.appendRow(['إجمالي الفاتورة', (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble() - (first['additionalExpenses'] ?? 0).toDouble()]);
      
      bool isMulti = primaryPaid > 0 && secondaryPaid > 0;

      if (primaryPaid > 0 || (primaryPaid == 0 && secondaryPaid == 0)) {
        String ptLabel = isMulti ? 'طريقه دفع 1' : 'طريقة الدفع';
        purchasesSheet.appendRow([ptLabel, first['paymentType'] ?? 'كاش']);
        purchasesSheet.appendRow(['الخزنة', first['wallet'] ?? 'نقدي']);
        purchasesSheet.appendRow(['المبلغ المدفوع', primaryPaid]);
      }
      if (secondaryPaid > 0) {
        final secRecord = records.firstWhere((r) => r['invoiceId'] == invoiceId && r['type'] == 'supplier_settlement');
        String ptLabel = isMulti ? 'طريقة دفع 2' : 'طريقة الدفع';
        purchasesSheet.appendRow([ptLabel, isMulti ? 'تحويل/سداد' : (secRecord['paymentType'] ?? 'تحويل')]);
        purchasesSheet.appendRow(['الخزنة', secRecord['wallet'] ?? 'نقدي']);
        purchasesSheet.appendRow(['المبلغ المدفوع', secondaryPaid]);
      }
      purchasesSheet.appendRow(['إجمالي المدفوع', totalPaid]);
      purchasesSheet.appendRow(['الخصم', first['discount'] ?? 0]);
      purchasesSheet.appendRow(['مصاريف إضافية', first['additionalExpenses'] ?? 0]);
      purchasesSheet.appendRow([]);
      purchasesSheet.appendRow(['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي', 'الحالة']);
      for (var item in invoiceItems) {
        purchasesSheet.appendRow([item['item'], item['qty'], item['price'], item['total'], item['isReturn'] == true ? 'مرتجع للمورد' : 'شراء']);
      }
      purchasesSheet.appendRow([]);
    }

    // --- 8. العملاء الجدد ---
    var newCustomersSheet = excel['العملاء الجدد'];
    newCustomersSheet.appendRow(['اسم العميل']);
    var newCustomers = CustomerStore.getNewCustomersToday(dayStartTime);
    for (var name in newCustomers) {
      newCustomersSheet.appendRow([name]);
    }

    // --- 9. سداد العملاء ---
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

    // --- 10. المبيعات (التفصيلي) ---
    var salesSheet = excel['المبيعات'];
    for (final invoiceItems in salesByInvoice.values) {
      if (invoiceItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      final primaryPaid = (first['paidAmount'] as num).toDouble();
      final secondaryPaid = getSecondaryAmount(invoiceId, 'settlement');
      final totalPaid = primaryPaid + secondaryPaid;

      salesSheet.appendRow(['رقم الفاتورة', first['invoiceNumber']]);
      salesSheet.appendRow(['التاريخ', _formatDate(first['time'])]);
      salesSheet.appendRow(['إسم العميل', first['customer']]);
      salesSheet.appendRow(['إجمالي الفاتورة', (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble() - (first['additionalExpenses'] ?? 0).toDouble()]);
      
      bool isMulti = primaryPaid > 0 && secondaryPaid > 0;

      if (primaryPaid > 0 || (primaryPaid == 0 && secondaryPaid == 0)) {
        String ptLabel = isMulti ? 'طريقه دفع 1' : 'طريقة الدفع';
        salesSheet.appendRow([ptLabel, first['paymentType'] ?? 'كاش']);
        salesSheet.appendRow(['الخزنة', first['wallet'] ?? 'نقدي']);
        salesSheet.appendRow(['المبلغ المدفوع', primaryPaid]);
      }
      if (secondaryPaid > 0) {
        final secRecord = records.firstWhere((r) => r['invoiceId'] == invoiceId && r['type'] == 'settlement');
        String ptLabel = isMulti ? 'طريقة دفع 2' : 'طريقة الدفع';
        salesSheet.appendRow([ptLabel, isMulti ? 'تحويل/سداد' : (secRecord['paymentType'] ?? 'تحويل')]);
        salesSheet.appendRow(['الخزنة', secRecord['wallet'] ?? 'نقدي']);
        salesSheet.appendRow(['المبلغ المدفوع', secondaryPaid]);
      }
      salesSheet.appendRow(['إجمالي المدفوع', totalPaid]);
      salesSheet.appendRow(['الخصم', first['discount'] ?? 0]);
      salesSheet.appendRow(['مصاريف إضافية', first['additionalExpenses'] ?? 0]);
      salesSheet.appendRow([]);
      salesSheet.appendRow(['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي', 'الحالة']);
      for (var item in invoiceItems) {
        salesSheet.appendRow([item['item'], item['qty'], item['price'], item['total'], item['isReturn'] == true ? 'مرتجع' : 'بيع']);
      }
      salesSheet.appendRow([]);
    }

    // --- 11. المبيعات أوتو ---
    var salesAutoSheet = excel['المبيعات أوتو'];
    salesAutoSheet.appendRow(['اسم عميل', 'اسم الصنف', 'الكميه', 'سعر الوحده', 'الخزنه', 'المدفوع', 'الخصم', 'مصاريف إضافية']);
    for (final invoiceItems in salesByInvoice.values) {
      final nonReturnItems = invoiceItems.where((item) => item['isReturn'] != true).toList();
      if (nonReturnItems.isEmpty) continue;
      final first = invoiceItems.first;
      final invoiceId = first['invoiceId'];
      for (var item in nonReturnItems) {
        salesAutoSheet.appendRow([item['customer'], item['item'], item['qty'], item['price'], '', '', '', '']);
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
        String rawPT = first['paymentType'] ?? 'كاش';
        if (rawPT == 'آجل') {
          displayPaid = 0;
          displayWallet = 'نقدي';
        } else {
          displayPaid = primaryPaid;
          displayWallet = (rawPT == 'كاش' ? 'نقدي' : (first['wallet'] ?? ''));
        }
      }
      salesAutoSheet.appendRow(['', '', '', '', displayWallet, displayPaid, first['discount'] ?? 0, first['additionalExpenses'] ?? 0]);
    }

    // --- 12. المرتجعات ---
    var returnsSheet = excel['المرتجعات'];
    returnsSheet.appendRow(['المورد/العميل', 'الصنف', 'الكمية', 'السعر', 'الإجمالي', 'النوع']);
    for (var r in records.where((e) => (e['type'] == 'purchase' || e['type'] == 'sale' || e['type'] == 'sales_return') && e['isReturn'] == true)) {
      returnsSheet.appendRow([r['supplier'] ?? r['customer'], r['item'], r['qty'], r['price'], r['total'], r['type'] == 'purchase' ? 'مرتجع شراء' : 'مرتجع بيع']);
    }

    // --- 13. المسحوبات الشخصية ---
    var withdrawSheet = excel['المسحوبات الشخصية'];
    withdrawSheet.appendRow(['المبلغ', 'الشخص', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'withdraw')) {
      withdrawSheet.appendRow([r['amount'], r['person'] ?? '', r['description'] ?? r['reason'] ?? '', r['source'] ?? r['wallet'] ?? 'نقدي']);
    }

    // --- 14. مصروفات الشغل ---
    var expenses = excel['مصروفات الشغل'];
    expenses.appendRow(['المبلغ', 'البيان', 'الخزنة']);
    for (var r in records.where((e) => e['type'] == 'expense')) {
      expenses.appendRow([r['amount'], r['description'] ?? r['reason'] ?? '', r['source'] ?? r['wallet'] ?? 'نقدي']);
    }

    // --- 15. المخلص ---
    var summarySheet = excel['المخلص'];
    summarySheet.isRTL = true;
    summarySheet.appendRow(['البيان', 'التفاصيل', 'المبلغ']);

    final walletsList = CashState.instance.wallets.keys.toList();
    final orderedWallets = ['نقدي', ...walletsList];

    // --- بداية اليوم ---
    double totalInitial = 0;
    for (var w in orderedWallets) {
      totalInitial += CashState.instance.getInitialBalance(w);
    }
    summarySheet.appendRow(['--- بداية اليوم ---', '', totalInitial]);
    for (var w in orderedWallets) {
      summarySheet.appendRow(['', w == 'نقدي' ? 'نقدي (كاش)' : w, CashState.instance.getInitialBalance(w)]);
    }

    // --- المشتريات ---
    double purTotalVal = 0;
    double purTotalPaid = 0;
    double purTotalDisc = 0;
    for (final invoiceItems in purchasesByInvoice.values) {
      final first = invoiceItems.first;
      purTotalVal += (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble() - (first['additionalExpenses'] ?? 0).toDouble();
      purTotalDisc += (first['discount'] as num).toDouble();
      final invoiceId = first['invoiceId'];
      purTotalPaid += (first['paidAmount'] as num).toDouble() + getSecondaryAmount(invoiceId, 'supplier_settlement');
    }
    summarySheet.appendRow(['--- المشتريات ---', '', '']);
    summarySheet.appendRow(['', 'إجمالي قيمة المشتريات', purTotalVal]);
    summarySheet.appendRow(['', 'إجمالي ما تم دفعه (شامل المتعدد)', purTotalPaid]);
    summarySheet.appendRow(['', 'إجمالي الخصم', purTotalDisc]);
    summarySheet.appendRow(['', 'المتبقي علينا (آجل من مشتريات اليوم)', (purTotalVal - purTotalDisc) - purTotalPaid]);

    // --- المبيعات ---
    double saleTotalVal = 0;
    double saleTotalReceived = 0;
    double saleTotalDisc = 0;
    for (final invoiceItems in salesByInvoice.values) {
      final first = invoiceItems.first;
      saleTotalVal += (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num).toDouble() - (first['additionalExpenses'] ?? 0).toDouble();
      saleTotalDisc += (first['discount'] as num).toDouble();
      final invoiceId = first['invoiceId'];
      saleTotalReceived += (first['paidAmount'] as num).toDouble() + getSecondaryAmount(invoiceId, 'settlement');
    }
    summarySheet.appendRow(['--- المبيعات ---', '', '']);
    summarySheet.appendRow(['', 'إجمالي قيمة المبيعات', saleTotalVal]);
    summarySheet.appendRow(['', 'إجمالي ما تم استلامه (شامل المتعدد)', saleTotalReceived]);
    summarySheet.appendRow(['', 'إجمالي الخصم', saleTotalDisc]);
    summarySheet.appendRow(['', 'المتبقي لنا بره (آجل من مبيعات اليوم)', (saleTotalVal - saleTotalDisc) - saleTotalReceived]);

    // --- المصروفات والمسحوبات ---
    double expTotal = records.where((e) => e['type'] == 'expense').fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    double withTotal = records.where((e) => e['type'] == 'withdraw').fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    summarySheet.appendRow(['--- المصروفات والمسحوبات ---', '', '']);
    summarySheet.appendRow(['', 'إجمالي المصروفات', expTotal]);
    summarySheet.appendRow(['', 'إجمالي المسحوبات الشخصية', withTotal]);

    // --- تحصيل ودفع مديونيات سابقة ---
    double collTotal = records
        .where((e) => e['type'] == 'settlement' && (e['invoiceId'] == null || !salesByInvoice.containsKey(e['invoiceId'])))
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    double payTotal = records
        .where((e) => e['type'] == 'supplier_settlement' && (e['invoiceId'] == null || !purchasesByInvoice.containsKey(e['invoiceId'])))
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

    summarySheet.appendRow(['--- تحصيل ودفع مديونيات سابقة ---', '', '']);
    summarySheet.appendRow(['', 'إجمالي تحصيل من عملاء (سداد)', collTotal]);
    summarySheet.appendRow(['', 'إجمالي دفع لموردين (سداد)', payTotal]);

    // --- السيولة المتوفرة نهاية اليوم ---
    double totalCurrent = 0;
    for (var w in orderedWallets) {
      totalCurrent += CashState.instance.getBalance(w);
    }
    summarySheet.appendRow(['--- السيولة المتوفرة نهاية اليوم ---', '', totalCurrent]);
    for (var w in orderedWallets) {
      summarySheet.appendRow(['', w == 'نقدي' ? 'نقدي (كاش)' : w, CashState.instance.getBalance(w)]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      String fileName = "تقرير_يومي_$reportDate.xlsx";
      String fullPath = "$targetDirPath/$fileName";
      File(fullPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      return fullPath;
    }
    return "";
  }
}
