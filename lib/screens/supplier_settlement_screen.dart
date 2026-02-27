import 'package:aimex/models/supplier.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';
import 'package:hive_flutter/hive_flutter.dart';


class SupplierSettlementScreen extends StatefulWidget {
  const SupplierSettlementScreen({super.key});

  @override
  State<SupplierSettlementScreen> createState() =>
      _SupplierSettlementScreenState();
}

class _SupplierSettlementScreenState
    extends State<SupplierSettlementScreen> {

  final supplierController = TextEditingController();
  final amountController = TextEditingController();
  String? selectedWallet;
  final _supplierFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  @override
  void dispose() {
    supplierController.dispose();
    amountController.dispose();
    _supplierFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _saveSettlement() {
    if (!DayState.instance.dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final supplier = supplierController.text.trim();
    final amount = double.tryParse(amountController.text) ?? 0;

    if (supplier.isEmpty || amount <= 0) {
      ToastService.show('ادخل اسم المورد ومبلغ صحيح');
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

    DayRecordsStore.addRecord({
      'type': 'supplier_settlement',
      'supplier': supplier,
      'amount': amount,
      'wallet': selectedWallet ?? 'نقدي',
      'date': DateTime.now().toString(),
    });

    //TODO: I will add a supplier store later.

    amountController.clear();
    supplierController.clear();
    _supplierFocusNode.requestFocus();

    ToastService.show('تم تسجيل سداد المورد');
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ['نقدي', ...CashState.instance.wallets.keys.toList()];

    return Scaffold(
      appBar:
      AppBar(title: const Text('سداد الموردين')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SelectableTextField(
              controller: supplierController,
              focusNode: _supplierFocusNode,
              labelText: 'اسم المورد',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _amountFocusNode.requestFocus(),
            ),
            const SizedBox(height: 12),
            SelectableTextField(
              controller: amountController,
              focusNode: _amountFocusNode,
              keyboardType:
              TextInputType.number,
              labelText: 'المبلغ المدفوع',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveSettlement(),
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
                onPressed: _saveSettlement,
                child:
                const Text('حفظ السداد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
