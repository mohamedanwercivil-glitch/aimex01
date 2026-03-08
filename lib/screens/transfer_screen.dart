import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import '../state/cash_state.dart';
import '../data/day_records_store.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  String? fromBox;
  String? toBox;
  final amountController = TextEditingController();
  final feeController = TextEditingController();
  final _fromBoxFocusNode = FocusNode();
  final _toBoxFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _feeFocusNode = FocusNode();
  final _transferButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fromBoxFocusNode.requestFocus();
    });
    amountController.addListener(_updateFee);
  }

  void _updateFee() {
    if (fromBox != null && fromBox != 'نقدي' && toBox == 'نقدي') {
      final amount = double.tryParse(amountController.text) ?? 0;
      final fee = amount * 0.01;
      feeController.text = fee.toStringAsFixed(2);
    } else {
      feeController.clear();
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    feeController.dispose();
    _fromBoxFocusNode.dispose();
    _toBoxFocusNode.dispose();
    _amountFocusNode.dispose();
    _feeFocusNode.dispose();
    _transferButtonFocusNode.dispose();
    super.dispose();
  }

  void _transfer() {
    final amount = double.tryParse(amountController.text) ?? 0;
    final fee = double.tryParse(feeController.text) ?? 0;

    if (fromBox == null || toBox == null || amount <= 0) {
      ToastService.show('اكمل البيانات');
      return;
    }

    if (fromBox == toBox) {
      ToastService.show('لا يمكن التحويل إلى نفس الخزنة');
      return;
    }

    // شرط أساسي لرسوم التحويل
    if (fromBox != 'نقدي' && fee <= 0) {
      ToastService.show('يجب كتابة رسوم التحويل');
      return;
    }

    // إجمالي المبلغ الذي سيخصم من المحفظة الأصلية هو (المبلغ + الرسوم)
    final totalToWithdraw = amount + fee;

    final success = CashState.instance.transfer(
      from: fromBox!,
      to: toBox!,
      amount: amount,
    );

    if (!success) {
      ToastService.show('رصيد غير كافي أو خطأ في البيانات');
      return;
    }

    // خصم الرسوم من الخزنة المحول منها
    if (fee > 0) {
      if (fromBox == 'نقدي') {
        CashState.instance.withdrawCash(fee);
      } else {
        CashState.instance.withdrawFromWallet(fromBox!, fee);
      }
    }

    DayRecordsStore.addRecord({
      'type': 'transfer',
      'from': fromBox,
      'to': toBox,
      'amount': amount,
      'fee': fee,
      'date': DateTime.now().toString(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final boxes = CashState.instance.allBoxes;
    final showFeeField = fromBox != null && fromBox != 'نقدي';

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل الفلوس')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              focusNode: _fromBoxFocusNode,
              value: fromBox,
              decoration: const InputDecoration(
                labelText: 'التحويل من',
                border: OutlineInputBorder(),
              ),
              items: boxes
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  fromBox = value;
                  _updateFee();
                });
                _toBoxFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              focusNode: _toBoxFocusNode,
              value: toBox,
              decoration: const InputDecoration(
                labelText: 'التحويل إلى',
                border: OutlineInputBorder(),
              ),
              items: boxes
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  toBox = value;
                  _updateFee();
                });
                _amountFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            SelectableTextField(
              focusNode: _amountFocusNode,
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              labelText: 'المبلغ',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                if (showFeeField) {
                  _feeFocusNode.requestFocus();
                } else {
                  _transferButtonFocusNode.requestFocus();
                }
              },
            ),
            if (showFeeField) ...[
              const SizedBox(height: 12),
              SelectableTextField(
                focusNode: _feeFocusNode,
                controller: feeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                labelText: 'رسوم التحويل',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _transferButtonFocusNode.requestFocus(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                focusNode: _transferButtonFocusNode,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: _transfer,
                child: const Text('تنفيذ التحويل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
