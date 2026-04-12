import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/logger_service.dart';

class CashState extends ChangeNotifier {
  static final CashState instance = CashState._internal();
  CashState._internal() {
    loadFromStorage();
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

  void loadFromStorage() {
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

  double getBalance(String boxName) {
    if (boxName == 'نقدي') return cash;
    return wallets[boxName] ?? 0.0;
  }

  double getInitialBalance(String boxName) {
    if (boxName == 'نقدي') return startOfDayCash;
    return startOfDayWallets[boxName] ?? 0.0;
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
    LoggerService.log(
      level: 'ADMIN',
      action: 'SET_START_OF_DAY',
      entity: 'system_balance',
      details: 'manual_admin_reset',
      before: 'cash=$startOfDayCash, wallets=$startOfDayWallets',
      after: 'cash=$startCash, wallets=$startWallets',
    );

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

  void depositCash(double amount, [String reason = "إيداع نقدي"]) {
    double before = cash;
    cash += amount;
    _save();
    LoggerService.logFinanceChange(
      walletName: 'نقدي',
      amount: amount,
      before: before,
      after: cash,
      reason: reason,
    );
    notifyListeners();
  }

  void withdrawCash(double amount, [String reason = "سحب نقدي"]) {
    double before = cash;
    cash -= amount;
    _save();
    LoggerService.logFinanceChange(
      walletName: 'نقدي',
      amount: -amount,
      before: before,
      after: cash,
      reason: reason,
    );
    notifyListeners();
  }

  void depositToWallet(String wallet, double amount, [String reason = "إيداع للمحفظة"]) {
    if (wallets.containsKey(wallet)) {
      double before = wallets[wallet]!;
      wallets[wallet] = before + amount;
      _save();
      LoggerService.logFinanceChange(
        walletName: wallet,
        amount: amount,
        before: before,
        after: wallets[wallet]!,
        reason: reason,
      );
      notifyListeners();
    }
  }

  void withdrawFromWallet(String wallet, double amount, [String reason = "سحب من المحفظة"]) {
    if (wallets.containsKey(wallet)) {
      double before = wallets[wallet]!;
      wallets[wallet] = before - amount;
      _save();
      LoggerService.logFinanceChange(
        walletName: wallet,
        amount: -amount,
        before: before,
        after: wallets[wallet]!,
        reason: reason,
      );
      notifyListeners();
    }
  }

  bool transfer({
    required String from,
    required String to,
    required double amount,
  }) {
    if (from == to || amount <= 0) return false;

    if (from == 'نقدي') {
      withdrawCash(amount, "تحويل صادر إلى $to");
    } else {
      withdrawFromWallet(from, amount, "تحويل صادر إلى $to");
    }

    if (to == 'نقدي') {
      depositCash(amount, "تحويل وارد من $from");
    } else {
      depositToWallet(to, amount, "تحويل وارد من $from");
    }

    return true;
  }
}
