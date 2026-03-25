import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CashState extends ChangeNotifier {
  static final CashState instance = CashState._internal();
  CashState._internal() {
    _loadFromStorage();
  }

  static const String _boxName = 'dayBox';
  Box get _box => Hive.box(_boxName);

  double cash = 0;
  double startOfDayCash = 0;

  Map<String, double> wallets = {
    'فودافون محمد 32': 0,
    'فودافون محمد 57': 0,
    'وي محمد': 0,
    'فودافون عمر': 0,
    'انستا محمد 015': 0,
  };
  Map<String, double> startOfDayWallets = {};

  void _loadFromStorage() {
    cash = (_box.get('cash', defaultValue: 0.0) as num).toDouble();
    startOfDayCash = (_box.get('startOfDayCash', defaultValue: 0.0) as num).toDouble();

    final savedWallets = _box.get('wallets');
    if (savedWallets != null && savedWallets is Map) {
      savedWallets.forEach((key, value) {
        if (wallets.containsKey(key)) {
          wallets[key] = (value as num).toDouble();
        }
      });
    }

    final savedStartWallets = _box.get('startOfDayWallets');
    if (savedStartWallets != null && savedStartWallets is Map) {
      savedStartWallets.forEach((key, value) {
        startOfDayWallets[key.toString()] = (value as num).toDouble();
      });
    }
    notifyListeners();
  }

  void _save() {
    _box.put('cash', cash);
    _box.put('startOfDayCash', startOfDayCash);
    _box.put('wallets', wallets);
    _box.put('startOfDayWallets', startOfDayWallets);
  }

  List<String> get allBoxes {
    return ['نقدي', ...wallets.keys];
  }

  double get totalMoney {
    double total = cash;
    for (var value in wallets.values) {
      total += value;
    }
    return total;
  }

  void setStartOfDay({
    required double startCash,
    required Map<String, double> startWallets,
  }) {
    cash = startCash;
    startOfDayCash = startCash;
    
    // تصفير البدايات القديمة
    startOfDayWallets.clear();
    wallets.updateAll((key, value) => 0);

    startWallets.forEach((key, value) {
      if (wallets.containsKey(key)) {
        wallets[key] = value;
        startOfDayWallets[key] = value;
      }
    });
    _save();
    notifyListeners();
  }

  void depositCash(double amount) {
    cash += amount;
    _save();
    notifyListeners();
  }

  void withdrawCash(double amount) {
    cash -= amount;
    _save();
    notifyListeners();
  }

  void depositToWallet(String wallet, double amount) {
    if (wallets.containsKey(wallet)) {
      wallets[wallet] = wallets[wallet]! + amount;
      _save();
      notifyListeners();
    }
  }

  void withdrawFromWallet(String wallet, double amount) {
    if (wallets.containsKey(wallet)) {
      wallets[wallet] = wallets[wallet]! - amount;
      _save();
      notifyListeners();
    }
  }

  bool transfer({
    required String from,
    required String to,
    required double amount,
  }) {
    if (from == to) return false;
    if (amount <= 0) return false;

    if (from == 'نقدي') {
      cash -= amount;
    } else {
      if (wallets.containsKey(from)) {
        wallets[from] = wallets[from]! - amount;
      }
    }

    if (to == 'نقدي') {
      cash += amount;
    } else {
      if (wallets.containsKey(to)) {
        wallets[to] = wallets[to]! + amount;
      }
    }

    _save();
    notifyListeners();
    return true;
  }
}
