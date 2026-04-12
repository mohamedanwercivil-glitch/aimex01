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
    String? reason,
  }) {
    if (paymentType == 'كاش' || paymentType == 'نقدي') {
      CashState.instance.depositCash(amount, reason ?? 'إيداع نقدي');
      return FinanceResult(true, 'تم إضافة المبلغ للكاش');
    }

    if (paymentType == 'تحويل') {
      if (walletName == null ||
          !CashState.instance.wallets.containsKey(walletName)) {
        return FinanceResult(false, 'المحفظة غير موجودة');
      }

      CashState.instance.depositToWallet(walletName, amount, reason ?? 'إيداع للمحفظة');
      return FinanceResult(true, 'تم إضافة المبلغ للمحفظة');
    }

    return FinanceResult(false, 'طريقة دفع غير صحيحة');
  }

  static FinanceResult withdraw({
    required double amount,
    required String paymentType,
    String? walletName,
    bool allowNegative = false,
    bool dryRun = false,
    String? reason,
  }) {
    if (paymentType == 'كاش' || paymentType == 'نقدي') {
      final currentCash = CashState.instance.cash;
      if (!allowNegative && currentCash < amount) {
        return FinanceResult(false, 
          'عذراً، الرصيد النقدي غير كافي.\nالمطلوب: $amount | المتاح: $currentCash');
      }

      if (!dryRun) CashState.instance.withdrawCash(amount, reason ?? 'سحب نقدي');
      return FinanceResult(true, 'تم خصم المبلغ من الكاش');
    }

    if (paymentType == 'تحويل') {
      if (walletName == null ||
          !CashState.instance.wallets.containsKey(walletName)) {
        return FinanceResult(false, 'المحفظة غير موجودة');
      }

      final currentWalletBalance = CashState.instance.wallets[walletName] ?? 0;
      if (!allowNegative && currentWalletBalance < amount) {
        return FinanceResult(false, 
          'رصيد محفظة ($walletName) غير كافي.\nالمطلوب: $amount | المتاح: $currentWalletBalance');
      }

      if (!dryRun) CashState.instance.withdrawFromWallet(walletName, amount, reason ?? 'سحب من المحفظة');
      return FinanceResult(true, 'تم خصم المبلغ من المحفظة');
    }

    return FinanceResult(false, 'طريقة دفع غير صحيحة');
  }
}
