import 'package:flutter/material.dart';

class CashState extends ChangeNotifier {
  static final CashState instance = CashState._internal();
  CashState._internal();

  double cash = 0;

  final Map<String, double> wallets = {
    'فودافون محمد 32': 0,
    'فودافون محمد 57': 0,
    'وي محمد': 0,
    'فودافون عمر': 0,
  };

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

    wallets.updateAll((key, value) => 0);

    startWallets.forEach((key, value) {
      if (wallets.containsKey(key)) {
        wallets[key] = value;
      }
    });

    notifyListeners();
  }

  void depositCash(double amount) {
    cash += amount;
    notifyListeners();
  }

  void withdrawCash(double amount) {
    if (cash >= amount) {
      cash -= amount;
      notifyListeners();
    }
  }

  void depositToWallet(String wallet, double amount) {
    if (wallets.containsKey(wallet)) {
      wallets[wallet] =
          wallets[wallet]! + amount;
      notifyListeners();
    }
  }

  void withdrawFromWallet(String wallet, double amount) {
    if (wallets.containsKey(wallet) &&
        wallets[wallet]! >= amount) {
      wallets[wallet] =
          wallets[wallet]! - amount;
      notifyListeners();
    }
  }

  // 🔥 التحويل بين الخزن
  bool transfer({
    required String from,
    required String to,
    required double amount,
  }) {
    if (from == to) return false;
    if (amount <= 0) return false;

    double fromBalance =
    from == 'نقدي' ? cash : wallets[from] ?? 0;

    if (fromBalance < amount) return false;

    // خصم
    if (from == 'نقدي') {
      cash -= amount;
    } else {
      wallets[from] = wallets[from]! - amount;
    }

    // إضافة
    if (to == 'نقدي') {
      cash += amount;
    } else {
      wallets[to] = wallets[to]! + amount;
    }

    notifyListeners();
    return true;
  }
}
