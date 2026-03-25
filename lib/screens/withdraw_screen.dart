import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../data/day_records_store.dart';

class WithdrawScreen extends StatefulWidget {
  final String? editWithdrawId;
  const WithdrawScreen({super.key, this.editWithdrawId});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedPerson;
  String? selectedSource;

  final List<String> _people = ['محمد', 'عمر', 'امي'];
  final _amountFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editWithdrawId != null) {
      _loadWithdrawForEdit(widget.editWithdrawId!);
    } else {
      selectedSource = 'نقدي';
    }
  }

  void _loadWithdrawForEdit(String id) {
    final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
    setState(() {
      amountController.text = (record['amount'] ?? 0).toString();
      descriptionController.text = record['description'] ?? '';
      selectedPerson = record['person'];
      selectedSource = record['source'] ?? 'نقدي';
    });
  }

  void _deleteWithdrawPermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسحوب نهائياً؟'),
        content: const Text('سيتم استرداد مبلغ المسحوب للخزنة وحذفه من السجلات. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context); 
              if (widget.editWithdrawId != null) Navigator.pop(context);
              setState(() {});
              ToastService.show('تم حذف المسحوب واسترداد المبلغ');
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
    super.dispose();
  }

  void _saveWithdraw() {
    if (!context.read<DayState>().dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0;
    final person = selectedPerson;
    final source = selectedSource;
    final description = descriptionController.text.trim();

    if (amount <= 0 || person == null || source == null) {
      ToastService.show('الرجاء إدخال جميع البيانات بشكل صحيح');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.editWithdrawId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editWithdrawId!);
      }

      final result = FinanceService.withdraw(
        amount: amount,
        paymentType: source == 'نقدي' ? 'كاش' : 'تحويل',
        walletName: source == 'نقدي' ? null : source,
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
        'type': 'withdraw',
        'amount': amount,
        'person': person,
        'source': source,
        'description': description,
        'date': DateTime.now().toString(),
      });

      ToastService.show(widget.editWithdrawId != null ? 'تم تعديل المسحوب' : 'تم تسجيل المسحوب');

      if (widget.editWithdrawId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          descriptionController.clear();
          selectedPerson = null;
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
    final dayStarted = context.watch<DayState>().dayStarted;
    final cashState = context.watch<CashState>();
    final sources = cashState.allBoxes;
    final todayWithdrawals = DayRecordsStore.getAll()
        .where((r) => r['type'] == 'withdraw')
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editWithdrawId != null ? 'تعديل مسحوب' : 'مسحوبات شخصية'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSource,
                  decoration: const InputDecoration(labelText: 'مصدر السحب', border: OutlineInputBorder()),
                  items: sources.map((source) => DropdownMenuItem(value: source, child: Text(source))).toList(),
                  onChanged: (dayStarted && !_isSaving)
                      ? (value) => setState(() { selectedSource = value; _amountFocusNode.requestFocus(); })
                      : null,
                ),
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted && !_isSaving,
                  controller: amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: TextInputType.number,
                  labelText: 'المبلغ',
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPerson,
                  decoration: const InputDecoration(labelText: 'اسم الشخص', border: OutlineInputBorder()),
                  items: _people.map((person) => DropdownMenuItem(value: person, child: Text(person))).toList(),
                  onChanged: (dayStarted && !_isSaving)
                      ? (value) => setState(() { selectedPerson = value; _descriptionFocusNode.requestFocus(); })
                      : null,
                ),
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted && !_isSaving,
                  controller: descriptionController,
                  focusNode: _descriptionFocusNode,
                  labelText: 'البيان (اختياري)',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveWithdraw(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (dayStarted && !_isSaving) ? _saveWithdraw : null,
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ المسحوب'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('سجل مسحوبات اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todayWithdrawals.length,
              itemBuilder: (context, index) {
                final withdrawal = todayWithdrawals[index];
                final time = DateFormat('hh:mm a').format(DateTime.parse(withdrawal['date'] ?? withdrawal['time']));
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.brown),
                    title: Text('${withdrawal['person']}'),
                    subtitle: Text('المبلغ: ${withdrawal['amount']} | المصدر: ${withdrawal['source']} | $time'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawScreen(editWithdrawId: withdrawal['id'] ?? withdrawal['invoiceId']))).then((_) => setState(() {})),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteWithdrawPermanently(withdrawal['id'] ?? withdrawal['invoiceId']),
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
