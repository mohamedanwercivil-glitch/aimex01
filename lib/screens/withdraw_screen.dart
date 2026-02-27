import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../data/day_records_store.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

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

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cashState = context.read<CashState>();
      if (cashState.allBoxes.contains('نقدي')) {
        setState(() {
          selectedSource = 'نقدي';
        });
      }
    });
  }

  void _saveWithdraw() {
    if (!context.read<DayState>().dayStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب بدء اليوم أولاً')),
      );
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0;
    final person = selectedPerson;
    final source = selectedSource;
    final description = descriptionController.text.trim();

    if (amount <= 0 || person == null || source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال جميع البيانات بشكل صحيح')),
      );
      return;
    }

    final result = FinanceService.withdraw(
      amount: amount,
      paymentType: source == 'نقدي' ? 'كاش' : 'تحويل',
      walletName: source == 'نقدي' ? null : source,
    );

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    // 🔥 تسجيل المسحوب في سجل اليوم
    DayRecordsStore.addRecord({
      'type': 'withdraw',
      'amount': amount,
      'person': person,
      'source': source,
      'description': description,
      'date': DateTime.now().toString(),
    });

    amountController.clear();
    descriptionController.clear();
    setState(() {
      selectedPerson = null;
    });
    _amountFocusNode.requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل المسحوب')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayStarted = context.watch<DayState>().dayStarted;
    final cashState = context.watch<CashState>();
    final sources = cashState.allBoxes;

    return Scaffold(
      appBar: AppBar(title: const Text('مسحوبات شخصية')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedSource,
              decoration: const InputDecoration(
                labelText: 'مصدر السحب',
                border: OutlineInputBorder(),
              ),
              items: sources.map((source) {
                return DropdownMenuItem(value: source, child: Text(source));
              }).toList(),
              onChanged: dayStarted
                  ? (value) => setState(() {
                        selectedSource = value;
                        _amountFocusNode.requestFocus();
                      })
                  : null,
            ),
            const SizedBox(height: 12),
            SelectableTextField(
              enabled: dayStarted,
              controller: amountController,
              focusNode: _amountFocusNode,
              keyboardType: TextInputType.number,
              labelText: 'المبلغ',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                // You might want to open the person dropdown here
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedPerson,
              decoration: const InputDecoration(
                labelText: 'اسم الشخص',
                border: OutlineInputBorder(),
              ),
              items: _people.map((person) {
                return DropdownMenuItem(value: person, child: Text(person));
              }).toList(),
              onChanged: dayStarted
                  ? (value) => setState(() {
                        selectedPerson = value;
                        _descriptionFocusNode.requestFocus();
                      })
                  : null,
            ),
            const SizedBox(height: 12),
            SelectableTextField(
              enabled: dayStarted,
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
                onPressed: dayStarted ? _saveWithdraw : null,
                child: const Text('حفظ المسحوب'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
