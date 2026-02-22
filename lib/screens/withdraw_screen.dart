import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../data/day_records_store.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() =>
      _WithdrawScreenState();
}

class _WithdrawScreenState
    extends State<WithdrawScreen> {

  final amountController = TextEditingController();
  final personController = TextEditingController();
  final descriptionController = TextEditingController();

  void _saveWithdraw() {
    if (!DayState.instance.dayStarted) return;

    final amount =
        double.tryParse(amountController.text) ?? 0;
    final person =
    personController.text.trim();
    final description =
    descriptionController.text.trim();

    if (amount <= 0 || person.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'ادخل مبلغ واسم شخص صحيح')),
      );
      return;
    }

    final result = FinanceService.withdraw(
      amount: amount,
      paymentType: 'كاش',
    );

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
          SnackBar(content: Text(result.message)));
      return;
    }

    // 🔥 تسجيل المسحوب في سجل اليوم
    DayRecordsStore.addRecord({
      'type': 'withdraw',
      'amount': amount,
      'person': person,
      'description': description,
      'date': DateTime.now().toString(),
    });

    amountController.clear();
    personController.clear();
    descriptionController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم تسجيل المسحوب')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: const Text('المسحوبات')),
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
              controller: personController,
              decoration:
              const InputDecoration(
                labelText: 'اسم الشخص',
                border:
                OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration:
              const InputDecoration(
                labelText: 'البيان (اختياري)',
                border:
                OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveWithdraw,
                child:
                const Text('حفظ المسحوب'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
