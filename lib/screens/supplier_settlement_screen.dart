import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';
import '../data/supplier_store.dart';

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
      walletName: selectedWallet == 'نقدي' ? null : selectedWallet,
    );

    if (!result.success) {
      ToastService.show(result.message);
      return;
    }

    // تحديث رصيد المورد في المخزن (سداد ينقص المديونية)
    SupplierStore.updateBalance(supplier, -amount);

    DayRecordsStore.addRecord({
      'type': 'supplier_settlement',
      'supplier': supplier,
      'amount': amount,
      'wallet': selectedWallet ?? 'نقدي',
      'date': DateTime.now().toString(),
    });

    amountController.clear();
    supplierController.clear();
    _supplierFocusNode.requestFocus();

    ToastService.show('تم تسجيل سداد المورد وتحديث الحساب');
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ['نقدي', ...CashState.instance.wallets.keys.toList()];

    return Scaffold(
      appBar: AppBar(title: const Text('سداد الموردين')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchableDropdownField(
                controller: supplierController,
                focusNode: _supplierFocusNode,
                label: 'اسم المورد',
                onSearch: (value) => SupplierStore.searchSuppliers(value),
                onSelected: (_) => _amountFocusNode.requestFocus(),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                controller: amountController,
                focusNode: _amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  child: const Text('حفظ السداد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
