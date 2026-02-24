import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/day_records_store.dart';
import '../services/background_service.dart';

class DayState extends ChangeNotifier {
  static final DayState instance = DayState._internal();
  DayState._internal() {
    _loadFromStorage();
  }

  final Box box = Hive.box('dayBox');

  bool dayStarted = false;
  double cashStart = 0;
  double totalSales = 0;
  double totalExpenses = 0;

  DateTime? dayStartTime;
  DateTime? dayEndTime;

  Future<void> _loadFromStorage() async {
    dayStarted = box.get('dayStarted', defaultValue: false);
    cashStart = box.get('cashStart', defaultValue: 0.0);
    totalSales = box.get('totalSales', defaultValue: 0.0);
    totalExpenses = box.get('totalExpenses', defaultValue: 0.0);

    final start = box.get('dayStartTime');
    final end = box.get('dayEndTime');

    if (start != null) dayStartTime = DateTime.parse(start);
    if (end != null) dayEndTime = DateTime.parse(end);

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('dayStarted', dayStarted);
  }

  Future<void> _saveToStorage() async {
    box.put('dayStarted', dayStarted);
    box.put('cashStart', cashStart);
    box.put('totalSales', totalSales);
    box.put('totalExpenses', totalExpenses);

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
    dayStarted = true;
    cashStart = startCash;
    totalSales = 0;
    totalExpenses = 0;

    dayStartTime = DateTime.now();
    dayEndTime = null;

    _saveToStorage();
    BackgroundService.scheduleEndOfDayTask();
    notifyListeners();
  }

  void addSale(double amount) {
    totalSales += amount;
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