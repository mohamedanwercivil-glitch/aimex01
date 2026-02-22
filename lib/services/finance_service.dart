import '../state/cash_state.dart';

class FinanceResult {
  final bool success;
  final String message;

  FinanceResult(this.success, this.message);
}

class FinanceService {
  static FinanceResult deposit({
    required double amount,
    required String paymentType,
    String? walletName,
  }) {
    if (paymentType == 'كاش') {
      CashState.instance.depositCash(amount);
      return FinanceResult(true, 'تم إضافة المبلغ للكاش');
    }

    if (paymentType == 'تحويل') {
      if (walletName == null ||
          !CashState.instance.wallets.containsKey(walletName)) {
        return FinanceResult(false, 'المحفظة غير موجودة');
      }

      CashState.instance.depositToWallet(walletName, amount);
      return FinanceResult(true, 'تم إضافة المبلغ للمحفظة');
    }

    return FinanceResult(false, 'طريقة دفع غير صحيحة');
  }

  static FinanceResult withdraw({
    required double amount,
    required String paymentType,
    String? walletName,
  }) {
    if (paymentType == 'كاش') {
      if (CashState.instance.cash < amount) {
        return FinanceResult(false, 'الرصيد النقدي غير كافي');
      }

      CashState.instance.withdrawCash(amount);
      return FinanceResult(true, 'تم خصم المبلغ من الكاش');
    }

    if (paymentType == 'تحويل') {
      if (walletName == null ||
          !CashState.instance.wallets.containsKey(walletName)) {
        return FinanceResult(false, 'المحفظة غير موجودة');
      }

      if (CashState.instance.wallets[walletName]! < amount) {
        return FinanceResult(false, 'رصيد المحفظة غير كافي');
      }

      CashState.instance.withdrawFromWallet(walletName, amount);
      return FinanceResult(true, 'تم خصم المبلغ من المحفظة');
    }

    return FinanceResult(false, 'طريقة دفع غير صحيحة');
  }
}
