import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/day_records_store.dart';
import '../services/background_service.dart';
import '../services/export_excel_service.dart';

class DayState extends ChangeNotifier {
  static final DayState instance = DayState._internal();
  DayState._internal() {
    loadFromStorage();
  }

  final Box box = Hive.box('dayBox');

  bool dayStarted = false;
  double cashStart = 0;
  double totalSales = 0;
  double totalExpenses = 0;
  
  // الحقول الجديدة للمشتريات والخصومات
  double totalPurchases = 0; 
  double totalPurchaseDiscount = 0;
  double totalSalesDiscount = 0;

  DateTime? dayStartTime;
  DateTime? dayEndTime;

  Future<void> loadFromStorage() async {
    dayStarted = box.get('dayStarted', defaultValue: false);
    cashStart = (box.get('cashStart', defaultValue: 0.0) as num).toDouble();
    totalSales = (box.get('totalSales', defaultValue: 0.0) as num).toDouble();
    totalExpenses = (box.get('totalExpenses', defaultValue: 0.0) as num).toDouble();
    
    totalPurchases = (box.get('totalPurchases', defaultValue: 0.0) as num).toDouble();
    totalPurchaseDiscount = (box.get('totalPurchaseDiscount', defaultValue: 0.0) as num).toDouble();
    totalSalesDiscount = (box.get('totalSalesDiscount', defaultValue: 0.0) as num).toDouble();

    final start = box.get('dayStartTime');
    final end = box.get('dayEndTime');

    if (start != null) dayStartTime = DateTime.parse(start);
    if (end != null) dayEndTime = DateTime.parse(end);

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('dayStarted', dayStarted);
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    box.put('dayStarted', dayStarted);
    box.put('cashStart', cashStart);
    box.put('totalSales', totalSales);
    box.put('totalExpenses', totalExpenses);
    
    box.put('totalPurchases', totalPurchases);
    box.put('totalPurchaseDiscount', totalPurchaseDiscount);
    box.put('totalSalesDiscount', totalSalesDiscount);

    if (dayStartTime != null) {
      box.put('dayStartTime', dayStartTime!.toIso8601String());
    }
    if (dayEndTime != null) {
      box.put('dayEndTime', dayEndTime!.toIso8601String());
    }

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('dayStarted', dayStarted);
  }

  void startDay(double startCash) {
    DayRecordsStore.clear();
    ExportExcelService.clearDailyInvoices();
    
    dayStarted = true;
    cashStart = startCash;
    totalSales = 0;
    totalExpenses = 0;
    totalPurchases = 0;
    totalPurchaseDiscount = 0;
    totalSalesDiscount = 0;

    dayStartTime = DateTime.now();
    dayEndTime = null;

    _saveToStorage();
    BackgroundService.scheduleEndOfDayTask();
    notifyListeners();
  }

  void addSale(double amount, {double discount = 0}) {
    totalSales += amount;
    totalSalesDiscount += discount;
    _saveToStorage();
    notifyListeners();
  }

  void addPurchase(double subtotal, {double discount = 0}) {
    totalPurchases += subtotal;
    totalPurchaseDiscount += discount;
    _saveToStorage();
    notifyListeners();
  }

  void addExpense(double amount) {
    totalExpenses += amount;
    _saveToStorage();
    notifyListeners();
  }

  Future<void> endDay() async {
    dayStarted = false;
    dayEndTime = DateTime.now();

    await _saveToStorage();
    BackgroundService.cancelEndOfDayTask();
    notifyListeners();
  }

  double get netProfit => totalSales - totalExpenses;
}
