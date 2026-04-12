import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';
import '../data/supplier_store.dart';

class SupplierSettlementScreen extends StatefulWidget {
  final String? editSettlementId;
  const SupplierSettlementScreen({super.key, this.editSettlementId});

  @override
  State<SupplierSettlementScreen> createState() =>
      _SupplierSettlementScreenState();
}

class _SupplierSettlementScreenState
    extends State<SupplierSettlementScreen> {

  final supplierController = TextEditingController();
  final amountController = TextEditingController();
  final remarksController = TextEditingController();
  
  String? selectedWallet;
  final _supplierFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _remarksFocusNode = FocusNode();
  bool _isSaving = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.editSettlementId != null) {
      _loadSettlementForEdit(widget.editSettlementId!);
    } else {
      selectedWallet = 'نقدي';
    }
    supplierController.addListener(_updateBalance);
  }

  void _updateBalance() {
    final name = supplierController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _currentBalance = SupplierStore.getBalance(name);
      });
    } else {
      setState(() {
        _currentBalance = 0.0;
      });
    }
  }

  void _loadSettlementForEdit(String id) {
    final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
    setState(() {
      supplierController.text = record['supplier'] ?? '';
      amountController.text = (record['amount'] ?? 0).toString();
      selectedWallet = record['wallet'] ?? 'نقدي';
      remarksController.text = record['remarks'] ?? '';
    });
  }

  void _deleteSettlementPermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عملية السداد نهائياً؟'),
        content: const Text('سيتم إلغاء أثر العملية من حساب المورد واسترداد/خصم المبلغ من الخزنة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context); 
              if (widget.editSettlementId != null) Navigator.pop(context);
              setState(() {});
              ToastService.show('تم حذف العملية وعكس أثرها');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    supplierController.dispose();
    amountController.dispose();
    remarksController.dispose();
    _supplierFocusNode.dispose();
    _amountFocusNode.dispose();
    _remarksFocusNode.dispose();
    super.dispose();
  }

  void _saveSettlement() {
    if (!DayState.instance.dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final supplier = supplierController.text.trim();
    final amount = double.tryParse(amountController.text) ?? 0;
    final remarks = remarksController.text.trim();

    if (supplier.isEmpty || amount == 0) {
      ToastService.show('ادخل اسم المورد ومبلغ صحيح');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.editSettlementId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editSettlementId!);
      }

      FinanceResult result;
      // إذا كان المبلغ موجب: أنت تدفع للمورد (سحب من الخزنة)
      // إذا كان المبلغ سالب: المورد يدفع لك (إيداع في الخزنة)
      if (amount > 0) {
        result = FinanceService.withdraw(
          amount: amount,
          paymentType: selectedWallet == 'نقدي' ? 'كاش' : 'تحويل',
          walletName: selectedWallet == 'نقدي' ? null : selectedWallet,
          reason: "سداد لمورد: $supplier",
          allowNegative: true,
        );
      } else {
        result = FinanceService.deposit(
          amount: amount.abs(),
          paymentType: selectedWallet == 'نقدي' ? 'كاش' : 'تحويل',
          walletName: selectedWallet == 'نقدي' ? null : selectedWallet,
          reason: "تحصيل من مورد: $supplier"
        );
      }

      if (!result.success) {
        ToastService.show(result.message);
        setState(() => _isSaving = false);
        return;
      }

      SupplierStore.addSupplier(supplier);
      SupplierStore.updateBalance(supplier, -amount);

      const uuid = Uuid();
      final id = uuid.v4();

      DayRecordsStore.addRecord({
        'id': id,
        'type': 'supplier_settlement',
        'supplier': supplier,
        'amount': amount,
        'wallet': selectedWallet ?? 'نقدي',
        'date': DateTime.now().toString(),
        'remarks': remarks,
      });

      ToastService.show(widget.editSettlementId != null ? 'تم تعديل العملية بنجاح' : 'تم تسجيل العملية وتحديث الحساب');

      if (widget.editSettlementId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          supplierController.clear();
          remarksController.clear();
          _isSaving = false;
        });
        _supplierFocusNode.requestFocus();
      }
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ['نقدي', ...CashState.instance.wallets.keys.toList()];
    final todaySupplierSettlements = DayRecordsStore.getAll()
        .where((r) => r['type'] == 'supplier_settlement')
        .toList()
        .reversed
        .toList();

    String balanceText = "";
    if (supplierController.text.trim().isNotEmpty) {
      if (_currentBalance > 0) {
        balanceText = " (له: ${_currentBalance.toStringAsFixed(2)})";
      } else if (_currentBalance < 0) {
        balanceText = " (عليه: ${_currentBalance.abs().toStringAsFixed(2)})";
      } else {
        balanceText = " (رصيده صفر)";
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.editSettlementId != null ? "تعديل عملية" : "سداد الموردين"}$balanceText'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SearchableDropdownField(
                  enabled: !_isSaving,
                  controller: supplierController,
                  focusNode: _supplierFocusNode,
                  label: 'اسم المورد',
                  onSearch: (value) => SupplierStore.searchSuppliers(value),
                  onSelected: (_) => _amountFocusNode.requestFocus(),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SelectableTextField(
                        enabled: !_isSaving,
                        controller: amountController,
                        focusNode: _amountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        labelText: 'المبلغ',
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _remarksFocusNode.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: SelectableTextField(
                        enabled: !_isSaving,
                        controller: remarksController,
                        focusNode: _remarksFocusNode,
                        labelText: 'ملاحظات',
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveSettlement(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWallet,
                  decoration: const InputDecoration(labelText: 'اختر الخزنة', border: OutlineInputBorder()),
                  items: wallets.map((wallet) => DropdownMenuItem(value: wallet, child: Text(wallet))).toList(),
                  onChanged: _isSaving ? null : (value) => setState(() => selectedWallet = value),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettlement,
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ العملية'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('سجل حركات سداد الموردين اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todaySupplierSettlements.length,
              itemBuilder: (context, index) {
                final settlement = todaySupplierSettlements[index];
                final time = DateFormat('hh:mm a').format(DateTime.parse(settlement['date'] ?? settlement['time']));
                final bool isBeingEdited = widget.editSettlementId != null && 
                    (settlement['id'] == widget.editSettlementId || settlement['invoiceId'] == widget.editSettlementId);
                final remarks = settlement['remarks'] ?? '';
                final amt = (settlement['amount'] as num).toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      amt > 0 ? Icons.payments : Icons.price_check,
                      color: amt > 0 ? Colors.indigo : Colors.green,
                    ),
                    title: Text('${settlement['supplier']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المبلغ: $amt | الخزنة: ${settlement['wallet']} | $time'),
                        if (remarks.isNotEmpty)
                          Text('ملاحظة: $remarks', style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isBeingEdited)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierSettlementScreen(editSettlementId: settlement['id'] ?? settlement['invoiceId']))).then((_) => setState(() {})),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteSettlementPermanently(settlement['id'] ?? settlement['invoiceId']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
