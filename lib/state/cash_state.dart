import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CashState extends ChangeNotifier {
  static final CashState instance = CashState._internal();
  CashState._internal();

  static const String _boxName = 'dayBox';

  Box get _box => Hive.box(_boxName);

  bool _initialized = false;

  double cash = 0;

  final Map<String, double> wallets = {
    'فودافون محمد 32': 0,
    'فودافون محمد 57': 0,
    'وي محمد': 0,
    'فودافون عمر': 0,
  };

  // ======================
  // يشتغل تلقائي أول استخدام فقط
  // ======================
  void _ensureInit() {
    if (_initialized) return;

    cash = (_box.get('cash', defaultValue: 0) as num).toDouble();

    final savedWallets =
    _box.get('wallets', defaultValue: <String, dynamic>{});

    if (savedWallets is Map) {
      savedWallets.forEach((key, value) {
        if (wallets.containsKey(key)) {
          wallets[key] = (value as num).toDouble();
        }
      });
    }

    _initialized = true;
  }

  void _save() {
    _box.put('cash', cash);
    _box.put('wallets', wallets);
  }

  List<String> get allBoxes {
    _ensureInit();
    return ['نقدي', ...wallets.keys];
  }

  double get totalMoney {
    _ensureInit();

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
    _ensureInit();

    cash = startCash;

    wallets.updateAll((key, value) => 0);

    startWallets.forEach((key, value) {
      if (wallets.containsKey(key)) {
        wallets[key] = value;
      }
    });

    _save();
    notifyListeners();
  }

  void depositCash(double amount) {
    _ensureInit();

    cash += amount;
    _save();
    notifyListeners();
  }

  void withdrawCash(double amount) {
    _ensureInit();

    if (cash >= amount) {
      cash -= amount;
      _save();
      notifyListeners();
    }
  }

  void depositToWallet(String wallet, double amount) {
    _ensureInit();

    if (wallets.containsKey(wallet)) {
      wallets[wallet] = wallets[wallet]! + amount;
      _save();
      notifyListeners();
    }
  }

  void withdrawFromWallet(String wallet, double amount) {
    _ensureInit();

    if (wallets.containsKey(wallet) &&
        wallets[wallet]! >= amount) {
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
    _ensureInit();

    if (from == to) return false;
    if (amount <= 0) return false;

    double fromBalance =
    from == 'نقدي' ? cash : wallets[from] ?? 0;

    if (fromBalance < amount) return false;

    if (from == 'نقدي') {
      cash -= amount;
    } else {
      wallets[from] = wallets[from]! - amount;
    }

    if (to == 'نقدي') {
      cash += amount;
    } else {
      wallets[to] = wallets[to]! + amount;
    }

    _save();
    notifyListeners();
    return true;
  }
}