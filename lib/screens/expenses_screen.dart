import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() =>
      _ExpensesScreenState();
}

class _ExpensesScreenState
    extends State<ExpensesScreen> {

  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  String? selectedWallet;

  void _saveExpense() {
    if (!DayState.instance.dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final amount =
        double.tryParse(amountController.text) ?? 0;
    final description =
    descriptionController.text.trim();

    if (amount <= 0 || description.isEmpty) {
      ToastService.show('ادخل مبلغ وبيان صحيح');
      return;
    }

    final result = FinanceService.withdraw(
      amount: amount,
      paymentType: selectedWallet == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: selectedWallet,
    );

    if (!result.success) {
      ToastService.show(result.message);
      return;
    }

    // 🔥 تسجيل المصروف في سجل اليوم
    DayRecordsStore.addRecord({
      'type': 'expense',
      'amount': amount,
      'description': description,
      'wallet': selectedWallet ?? 'نقدي',
      'date': DateTime.now().toString(),
    });

    DayState.instance.addExpense(amount);

    amountController.clear();
    descriptionController.clear();

    ToastService.show('تم تسجيل المصروف');
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ['نقدي', ...CashState.instance.wallets.keys.toList()];

    return Scaffold(
      appBar:
      AppBar(title: const Text('المصروفات')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SelectableTextField(
              controller: amountController,
              keyboardType:
              TextInputType.number,
              labelText: 'المبلغ',
            ),
            const SizedBox(height: 12),
            SelectableTextField(
              controller: descriptionController,
              labelText: 'بيان المصروف',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedWallet,
              decoration: const InputDecoration(
                labelText: 'اختر الخزنة',
                border: OutlineInputBorder(),
              ),
              items: wallets
                  .map((wallet) => DropdownMenuItem(
                        value: wallet,
                        child: Text(wallet),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedWallet = value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveExpense,
                child:
                const Text('حفظ المصروف'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
