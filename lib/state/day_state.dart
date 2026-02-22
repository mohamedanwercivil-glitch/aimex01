import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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

  void _loadFromStorage() {
    dayStarted = box.get('dayStarted', defaultValue: false);
    cashStart = box.get('cashStart', defaultValue: 0.0);
    totalSales = box.get('totalSales', defaultValue: 0.0);
    totalExpenses = box.get('totalExpenses', defaultValue: 0.0);
  }

  void _saveToStorage() {
    box.put('dayStarted', dayStarted);
    box.put('cashStart', cashStart);
    box.put('totalSales', totalSales);
    box.put('totalExpenses', totalExpenses);
  }

  void startDay(double startCash) {
    dayStarted = true;
    cashStart = startCash;
    totalSales = 0;
    totalExpenses = 0;
    _saveToStorage();
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

  void endDay() {
    dayStarted = false;
    cashStart = 0;
    totalSales = 0;
    totalExpenses = 0;
    _saveToStorage();
    notifyListeners();
  }

  double get netProfit => totalSales - totalExpenses;
}
