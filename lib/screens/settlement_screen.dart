import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
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
  final _customerFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  @override
  void dispose() {
    customerController.dispose();
    amountController.dispose();
    _customerFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

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

    // 🔥 تحديث رصيد العميل (السداد يطرح من المديونية)
    CustomerStore.addCustomer(customer);
    CustomerStore.updateBalance(customer, -amount);

    // تسجيل السداد في السجلات
    DayRecordsStore.addRecord({
      'type': 'settlement',
      'customer': customer,
      'amount': amount,
      'paymentType': paymentType,
      'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
      'date': DateTime.now().toString(),
    });

    amountController.clear();
    customerController.clear();
    selectedWallet = null;
    
    setState(() {}); 

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم تسجيل السداد وتحديث حساب العميل')),
    );
    _customerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final wallets =
    CashState.instance.wallets.keys.toList();

    return Scaffold(
      appBar:
      AppBar(title: const Text('سداد العملاء')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SearchableDropdownField(
              focusNode: _customerFocusNode,
              controller: customerController,
              label: 'اسم العميل',
              onSearch: (value) => CustomerStore.searchCustomers(value),
              onSelected: (_) => _amountFocusNode.requestFocus(),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 12),

            SelectableTextField(
              controller: amountController,
              focusNode: _amountFocusNode,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              labelText: 'المبلغ',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveSettlement(),
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
                const Text('تسجيل سداد العميل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
