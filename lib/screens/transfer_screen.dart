import 'package:flutter/material.dart';
import '../state/cash_state.dart';
import '../data/day_records_store.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() =>
      _TransferScreenState();
}

class _TransferScreenState
    extends State<TransferScreen> {

  String? fromBox;
  String? toBox;
  final amountController =
  TextEditingController();

  void _transfer() {
    final amount =
        double.tryParse(amountController.text) ?? 0;

    if (fromBox == null ||
        toBox == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
          content:
          Text('اكمل البيانات')));
      return;
    }

    final success =
    CashState.instance.transfer(
      from: fromBox!,
      to: toBox!,
      amount: amount,
    );

    if (!success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
          content: Text(
              'رصيد غير كافي أو خطأ في البيانات')));
      return;
    }

    // 🔥 تسجيل التحويل في سجل اليوم
    DayRecordsStore.addRecord({
      'type': 'transfer',
      'from': fromBox,
      'to': toBox,
      'amount': amount,
      'date': DateTime.now().toString(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final boxes =
        CashState.instance.allBoxes;

    return Scaffold(
      appBar:
      AppBar(title: const Text('تحويل الفلوس')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: fromBox,
              decoration:
              const InputDecoration(
                labelText: 'التحويل من',
                border:
                OutlineInputBorder(),
              ),
              items: boxes
                  .map((e) =>
                  DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ))
                  .toList(),
              onChanged: (value) =>
                  setState(() =>
                  fromBox = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: toBox,
              decoration:
              const InputDecoration(
                labelText: 'التحويل إلى',
                border:
                OutlineInputBorder(),
              ),
              items: boxes
                  .map((e) =>
                  DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ))
                  .toList(),
              onChanged: (value) =>
                  setState(() =>
                  toBox = value),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _transfer,
                child:
                const Text('تنفيذ التحويل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
