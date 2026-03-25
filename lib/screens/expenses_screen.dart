import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../data/day_records_store.dart';
import '../state/cash_state.dart';

class ExpensesScreen extends StatefulWidget {
  final String? editExpenseId;
  const ExpensesScreen({super.key, this.editExpenseId});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  String? selectedWallet;
  final _amountFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _saveButtonFocusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editExpenseId != null) {
      _loadExpenseForEdit(widget.editExpenseId!);
    } else {
      selectedWallet = 'نقدي';
    }
  }

  void _loadExpenseForEdit(String id) {
    final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
    setState(() {
      amountController.text = (record['amount'] ?? 0).toString();
      descriptionController.text = record['description'] ?? '';
      selectedWallet = record['wallet'] ?? 'نقدي';
    });
  }

  void _deleteExpensePermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف نهائياً؟'),
        content: const Text('سيتم استرداد مبلغ المصروف للخزنة/المحفظة وحذفه من السجلات. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context); 
              if (widget.editExpenseId != null) Navigator.pop(context);
              setState(() {}); 
              ToastService.show('تم حذف المصروف واسترداد المبلغ');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _saveButtonFocusNode.dispose();
    super.dispose();
  }

  void _saveExpense() {
    if (!DayState.instance.dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0;
    final description = descriptionController.text.trim();

    if (amount <= 0 || description.isEmpty) {
      ToastService.show('ادخل مبلغ وبيان صحيح');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.editExpenseId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editExpenseId!);
      }

      final result = FinanceService.withdraw(
        amount: amount,
        paymentType: selectedWallet == 'نقدي' ? 'كاش' : 'تحويل',
        walletName: selectedWallet,
      );

      if (!result.success) {
        ToastService.show(result.message);
        setState(() => _isSaving = false);
        return;
      }

      const uuid = Uuid();
      final id = uuid.v4();

      DayRecordsStore.addRecord({
        'id': id,
        'type': 'expense',
        'amount': amount,
        'description': description,
        'wallet': selectedWallet ?? 'نقدي',
        'date': DateTime.now().toString(),
      });

      DayState.instance.addExpense(amount);
      ToastService.show(widget.editExpenseId != null ? 'تم تعديل المصروف' : 'تم تسجيل المصروف');

      if (widget.editExpenseId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          descriptionController.clear();
          _isSaving = false;
        });
        _amountFocusNode.requestFocus();
      }
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ['نقدي', ...CashState.instance.wallets.keys.toList()];
    final todayExpenses = DayRecordsStore.getAll()
        .where((r) => r['type'] == 'expense')
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editExpenseId != null ? 'تعديل مصروف' : 'مصروفات الشغل'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SelectableTextField(
                  autofocus: true,
                  enabled: !_isSaving,
                  controller: amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: TextInputType.number,
                  labelText: 'المبلغ',
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
                ),
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: !_isSaving,
                  controller: descriptionController,
                  focusNode: _descriptionFocusNode,
                  labelText: 'بيان المصروف',
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
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
                    focusNode: _saveButtonFocusNode,
                    onPressed: _isSaving ? null : _saveExpense,
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ المصروف'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('سجل مصروفات اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todayExpenses.length,
              itemBuilder: (context, index) {
                final expense = todayExpenses[index];
                final time = DateFormat('hh:mm a').format(DateTime.parse(expense['date'] ?? expense['time']));
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.money_off, color: Colors.red),
                    title: Text('${expense['description']}'),
                    subtitle: Text('المبلغ: ${expense['amount']} | الخزنة: ${expense['wallet']} | $time'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesScreen(editExpenseId: expense['id'] ?? expense['invoiceId']))).then((_) => setState(() {})),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteExpensePermanently(expense['id'] ?? expense['invoiceId']),
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
