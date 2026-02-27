import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
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
  final _fromBoxFocusNode = FocusNode();
  final _toBoxFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _transferButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fromBoxFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    _fromBoxFocusNode.dispose();
    _toBoxFocusNode.dispose();
    _amountFocusNode.dispose();
    _transferButtonFocusNode.dispose();
    super.dispose();
  }

  void _transfer() {
    final amount =
        double.tryParse(amountController.text) ?? 0;

    if (fromBox == null ||
        toBox == null ||
        amount <= 0) {
      ToastService.show('اكمل البيانات');
      return;
    }

    if (fromBox == toBox) {
      ToastService.show('لا يمكن التحويل إلى نفس الخزنة');
      return;
    }

    final success =
    CashState.instance.transfer(
      from: fromBox!,
      to: toBox!,
      amount: amount,
    );

    if (!success) {
      ToastService.show('رصيد غير كافي أو خطأ في البيانات');
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
              focusNode: _fromBoxFocusNode,
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
              onChanged: (value) {
                setState(() =>
                fromBox = value);
                _toBoxFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              focusNode: _toBoxFocusNode,
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
              onChanged: (value) {
                setState(() =>
                toBox = value);
                _amountFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            SelectableTextField(
              focusNode: _amountFocusNode,
              controller: amountController,
              keyboardType:
              TextInputType.number,
              labelText: 'المبلغ',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _transferButtonFocusNode.requestFocus(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                focusNode: _transferButtonFocusNode,
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
