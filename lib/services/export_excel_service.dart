import 'dart:io';
import 'package:excel/excel.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';

class ExportExcelService {

  static Future<String> exportDay() async {

    var now = DateTime.now();
    String date =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    var excel = Excel.createExcel();
    var records = DayRecordsStore.getAll();

    excel.delete('Sheet1');

    // =========================
    // المبيعات
    // =========================
    var sales = excel['المبيعات_$date'];
    sales.appendRow([
      'العميل','الصنف','الكمية','السعر','الإجمالي',
      'دفع/أجل','طريقة الدفع','المحفظة'
    ]);

    for (var r in records.where((e)=>e['type']=='sale')) {
      sales.appendRow([
        r['customer'],
        r['item'],
        r['qty'],
        r['price'],
        r['total'],
        r['paymentStatus'],
        r['paymentType'],
        r['wallet']
      ]);
    }

    // =========================
    // المشتريات
    // =========================
    var purchases = excel['المشتريات_$date'];
    purchases.appendRow([
      'المورد','الصنف','الكمية','السعر','الإجمالي',
      'طريقة الدفع','المحفظة'
    ]);

    for (var r in records.where((e)=>e['type']=='purchase')) {
      purchases.appendRow([
        r['supplier'],
        r['item'],
        r['qty'],
        r['price'],
        r['total'],
        r['paymentType'],
        r['wallet']
      ]);
    }

    // =========================
    // المصروفات
    // =========================
    var expenses = excel['المصروفات_$date'];
    expenses.appendRow(['المبلغ','البيان']);

    for (var r in records.where((e)=>e['type']=='expense')) {
      expenses.appendRow([
        r['amount'],
        r['description']
      ]);
    }

    // =========================
    // المسحوبات
    // =========================
    var withdraws = excel['المسحوبات_$date'];
    withdraws.appendRow([
      'المبلغ','اسم الشخص','البيان'
    ]);

    for (var r in records.where((e)=>e['type']=='withdraw')) {
      withdraws.appendRow([
        r['amount'],
        r['person'],
        r['description']
      ]);
    }

    // =========================
    // التحويلات
    // =========================
    var transfers = excel['التحويلات_$date'];
    transfers.appendRow(['من','إلى','المبلغ']);

    for (var r in records.where((e)=>e['type']=='transfer')) {
      transfers.appendRow([
        r['from'],
        r['to'],
        r['amount']
      ]);
    }

    // =========================
    // السداد
    // =========================
    var settlement = excel['سداد_$date'];
    settlement.appendRow([
      'العميل','المبلغ','طريقة الدفع','المحفظة'
    ]);

    for (var r in records.where((e)=>e['type']=='settlement')) {
      settlement.appendRow([
        r['customer'],
        r['amount'],
        r['paymentType'],
        r['wallet']
      ]);
    }

    // =========================
    // ملخص اليوم
    // =========================
    var summary = excel['ملخص_$date'];
    summary.appendRow(['إجمالي الفلوس']);
    summary.appendRow([CashState.instance.totalMoney]);

    // 🔥 حفظ في Download/AIMEX
    String downloadPath = "/storage/emulated/0/Download/AIMEX/$date";

    Directory(downloadPath).createSync(recursive: true);

    String filePath =
        "$downloadPath/تقرير_اليوم_$date.xlsx";

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    DayRecordsStore.clear();

    return filePath;
  }
}
