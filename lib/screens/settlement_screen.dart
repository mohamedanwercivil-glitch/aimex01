import 'package:flutter/material.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../services/finance_service.dart';
import '../data/day_records_store.dart';
import '../data/customer_store.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() =>
      _SettlementScreenState();
}

class _SettlementScreenState
    extends State<SettlementScreen> {

  final customerController = TextEditingController();
  final amountController = TextEditingController();

  String paymentType = 'كاش';
  String? selectedWallet;

  void _saveSettlement() {
    if (!DayState.instance.dayStarted) return;

    final customer =
    customerController.text.trim();
    final amount =
        double.tryParse(amountController.text) ?? 0;

    if (customer.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('ادخل اسم عميل ومبلغ صحيح')),
      );
      return;
    }

    final result = FinanceService.deposit(
      amount: amount,
      paymentType: paymentType,
      walletName:
      paymentType == 'تحويل'
          ? selectedWallet
          : null,
    );

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
          SnackBar(content: Text(result.message)));
      return;
    }

    // 🔥 تسجيل السداد
    DayRecordsStore.addRecord({
      'type': 'settlement',
      'customer': customer,
      'amount': amount,
      'paymentType': paymentType,
      'wallet': selectedWallet,
      'date': DateTime.now().toString(),
    });

    CustomerStore.addCustomer(customer);

    amountController.clear();
    customerController.clear();
    selectedWallet = null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم تسجيل السداد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets =
    CashState.instance.wallets.keys.toList();

    return Scaffold(
      appBar:
      AppBar(title: const Text('سداد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Autocomplete<String>(
              optionsBuilder: (text) =>
                  CustomerStore.searchCustomers(
                      text.text),
              onSelected: (value) =>
              customerController.text =
                  value,
              fieldViewBuilder:
                  (context, controller,
                  focusNode, _) {
                controller.text =
                    customerController.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration:
                  const InputDecoration(
                    labelText: 'اسم العميل',
                    border:
                    OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                  customerController.text =
                      value,
                );
              },
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

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: paymentType,
              decoration:
              const InputDecoration(
                labelText: 'طريقة الدفع',
                border:
                OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'كاش',
                    child: Text('كاش')),
                DropdownMenuItem(
                    value: 'تحويل',
                    child: Text('تحويل')),
              ],
              onChanged: (value) =>
                  setState(() =>
                  paymentType = value!),
            ),

            if (paymentType == 'تحويل') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedWallet,
                decoration:
                const InputDecoration(
                  labelText:
                  'اختر المحفظة',
                  border:
                  OutlineInputBorder(),
                ),
                items: wallets
                    .map((wallet) =>
                    DropdownMenuItem(
                      value: wallet,
                      child:
                      Text(wallet),
                    ))
                    .toList(),
                onChanged: (value) =>
                    setState(() =>
                    selectedWallet =
                        value),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettlement,
                child:
                const Text('تسجيل السداد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
