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
    if (!DayState.instance.dayStarted) return;

    final amount =
        double.tryParse(amountController.text) ?? 0;
    final description =
    descriptionController.text.trim();

    if (amount <= 0 || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ادخل مبلغ وبيان صحيح')),
      );
      return;
    }

    final result = FinanceService.withdraw(
      amount: amount,
      paymentType: selectedWallet == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: selectedWallet,
    );

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
          SnackBar(content: Text(result.message)));
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم تسجيل المصروف')),
    );
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
            TextField(
              controller: amountController,
              keyboardType:
              TextInputType.number,
              decoration:
              const InputDecoration(
                labelText: 'المبلغ',
                border:
                OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration:
              const InputDecoration(
                labelText: 'بيان المصروف',
                border:
                OutlineInputBorder(),
              ),
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
