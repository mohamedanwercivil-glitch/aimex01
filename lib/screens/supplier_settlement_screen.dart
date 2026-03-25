import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
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
  String? selectedWallet;
  final _supplierFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editSettlementId != null) {
      _loadSettlementForEdit(widget.editSettlementId!);
    } else {
      selectedWallet = 'نقدي';
    }
  }

  void _loadSettlementForEdit(String id) {
    final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
    setState(() {
      supplierController.text = record['supplier'] ?? '';
      amountController.text = (record['amount'] ?? 0).toString();
      selectedWallet = record['wallet'] ?? 'نقدي';
    });
  }

  void _deleteSettlementPermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عملية السداد نهائياً؟'),
        content: const Text('سيتم إلغاء أثر السداد من حساب المورد واسترداد المبلغ للخزنة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context); 
              if (widget.editSettlementId != null) Navigator.pop(context);
              setState(() {});
              ToastService.show('تم حذف السداد وعكس أثره');
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

    setState(() => _isSaving = true);

    try {
      if (widget.editSettlementId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editSettlementId!);
      }

      final result = FinanceService.withdraw(
        amount: amount,
        paymentType: selectedWallet == 'نقدي' ? 'كاش' : 'تحويل',
        walletName: selectedWallet == 'نقدي' ? null : selectedWallet,
      );

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
      });

      ToastService.show(widget.editSettlementId != null ? 'تم تعديل السداد' : 'تم تسجيل سداد المورد وتحديث الحساب');

      if (widget.editSettlementId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          supplierController.clear();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editSettlementId != null ? 'تعديل سداد مورد' : 'سداد الموردين'),
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
                SelectableTextField(
                  enabled: !_isSaving,
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
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ السداد'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('سجل سدادات الموردين اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todaySupplierSettlements.length,
              itemBuilder: (context, index) {
                final settlement = todaySupplierSettlements[index];
                final time = DateFormat('hh:mm a').format(DateTime.parse(settlement['date'] ?? settlement['time']));
                final bool isBeingEdited = widget.editSettlementId != null && 
                    (settlement['id'] == widget.editSettlementId || settlement['invoiceId'] == widget.editSettlementId);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.payments, color: Colors.indigo),
                    title: Text('${settlement['supplier']}'),
                    subtitle: Text('المبلغ: ${settlement['amount']} | الخزنة: ${settlement['wallet']} | $time'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isBeingEdited) // 🔥 تم إضافة الشرط هنا لتختفي الأيقونة أثناء التعديل
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
