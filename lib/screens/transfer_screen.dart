import 'package:aimex/services/toast_service.dart';
import 'package:aimex/services/logger_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../state/cash_state.dart';
import '../data/day_records_store.dart';

class TransferScreen extends StatefulWidget {
  final String? editTransferId;
  const TransferScreen({super.key, this.editTransferId});

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    LoggerService.userAction('فتح شاشة التحويلات المالية', {'تعديل': widget.editTransferId != null});
    if (widget.editTransferId != null) {
      _loadTransferForEdit(widget.editTransferId!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fromBoxFocusNode.requestFocus();
      });
    }
    amountController.addListener(_updateFee);
  }

  void _loadTransferForEdit(String id) {
    try {
      final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
      setState(() {
        fromBox = record['from'];
        toBox = record['to'];
        amountController.text = (record['amount'] ?? 0).toString();
        feeController.text = (record['fee'] ?? 0).toString();
      });
      LoggerService.logicStep('تم تحميل بيانات التحويل للتعديل', data: {'id': id, 'من': fromBox, 'إلى': toBox});
    } catch (e) {
      LoggerService.error('فشل تحميل بيانات التحويل للتعديل', error: e);
    }
  }

  void _updateFee() {
    if (widget.editTransferId != null) return; 
    
    if (fromBox != null && fromBox != 'نقدي' && toBox == 'نقدي') {
      final amount = double.tryParse(amountController.text) ?? 0;
      final fee = amount * 0.01;
      feeController.text = fee.toStringAsFixed(2);
    } 
    else if (fromBox == 'نقدي' && toBox != null && toBox != 'نقدي') {
    }
    else {
      feeController.clear();
    }
  }

  void _deleteTransferPermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التحويل نهائياً؟'),
        content: const Text('سيتم إلغاء عملية التحويل وإرجاع المبالغ للمحافظ الأصلية. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              LoggerService.userAction('حذف عملية تحويل نهائياً', {'id': id});
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context); 
              if (widget.editTransferId != null) Navigator.pop(context);
              setState(() {}); 
              ToastService.show('تم إلغاء التحويل واسترداد المبالغ');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    amountController.removeListener(_updateFee);
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

    LoggerService.userAction('ضغط زر تنفيذ التحويل', {'من': fromBox, 'إلى': toBox, 'مبلغ': amount, 'رسوم': fee});

    if (fromBox == null || toBox == null || amount <= 0) {
      ToastService.show('اكمل البيانات');
      return;
    }

    if (fromBox == toBox) {
      ToastService.show('لا يمكن التحويل إلى نفس الخزنة');
      return;
    }

    setState(() => _isSaving = true);

    try {
      double balanceFromBefore = CashState.instance.getBalance(fromBox!);
      double balanceToBefore = CashState.instance.getBalance(toBox!);

      if (widget.editTransferId != null) {
        LoggerService.logicStep('تعديل تحويل: عكس الأثر القديم', data: {'id': widget.editTransferId});
        DayRecordsStore.reverseInvoiceEffects(widget.editTransferId!);
      }

      final success = CashState.instance.transfer(
        from: fromBox!,
        to: toBox!,
        amount: amount,
      );

      if (!success) {
        LoggerService.warn('فشل عملية التحويل: رصيد غير كافٍ في $fromBox');
        ToastService.show('رصيد غير كافي أو خطأ في البيانات');
        setState(() => _isSaving = false);
        return;
      }

      if (fee > 0) {
        if (fromBox == 'نقدي') {
          CashState.instance.withdrawCash(fee);
        } else {
          CashState.instance.withdrawFromWallet(fromBox!, fee);
        }
        LoggerService.logicStep('تم خصم رسوم التحويل', data: {'القيمة': fee});
      }

      const uuid = Uuid();
      final id = uuid.v4();

      DayRecordsStore.addRecord({
        'id': id,
        'type': 'transfer',
        'from': fromBox,
        'to': toBox,
        'amount': amount,
        'fee': fee,
        'date': DateTime.now().toString(),
      });

      LoggerService.stateChange('رصيد المصدر ($fromBox)', balanceFromBefore, CashState.instance.getBalance(fromBox!));
      LoggerService.stateChange('رصيد الوجهة ($toBox)', balanceToBefore, CashState.instance.getBalance(toBox!));

      ToastService.show(widget.editTransferId != null ? 'تم تعديل التحويل' : 'تم تنفيذ التحويل بنجاح');
      
      if (widget.editTransferId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          feeController.clear();
          fromBox = 'نقدي';
          toBox = null;
          _isSaving = false;
        });
        _fromBoxFocusNode.requestFocus();
      }
    } catch (e, stack) {
      LoggerService.error('خطأ قاتل أثناء التحويل المالي', error: e, stackTrace: stack);
      ToastService.show('حدث خطأ أثناء التحويل');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxes = CashState.instance.allBoxes;
    final showFeeField = fromBox != null && toBox != null;

    final todayTransfers = DayRecordsStore.getAll()
        .where((r) => r['type'] == 'transfer')
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editTransferId != null ? 'تعديل تحويل مالي' : 'تحويل الفلوس'),
        actions: [
          if (widget.editTransferId != null)
             IconButton(
               icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
               onPressed: _isSaving ? null : () => _deleteTransferPermanently(widget.editTransferId!),
             ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  focusNode: _fromBoxFocusNode,
                  value: fromBox,
                  decoration: const InputDecoration(labelText: 'التحويل من', border: OutlineInputBorder()),
                  items: boxes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: _isSaving ? null : (value) {
                    setState(() { fromBox = value; _updateFee(); });
                    LoggerService.userAction('تغيير جهة التحويل (من)', {'القيمة': value});
                    _toBoxFocusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  focusNode: _toBoxFocusNode,
                  value: toBox,
                  decoration: const InputDecoration(labelText: 'التحويل إلى', border: OutlineInputBorder()),
                  items: boxes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: _isSaving ? null : (value) {
                    setState(() { toBox = value; _updateFee(); });
                    LoggerService.userAction('تغيير جهة التحويل (إلى)', {'القيمة': value});
                    _amountFocusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: !_isSaving,
                  focusNode: _amountFocusNode,
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ',
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    if (showFeeField) _feeFocusNode.requestFocus();
                    else _transferButtonFocusNode.requestFocus();
                  },
                ),
                if (showFeeField) ...[
                  const SizedBox(height: 12),
                  SelectableTextField(
                    enabled: !_isSaving,
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
                    onPressed: _isSaving ? null : _transfer,
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('تنفيذ التحويل'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('سجل تحويلات اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todayTransfers.length,
              itemBuilder: (context, index) {
                final transfer = todayTransfers[index];
                final dateVal = transfer['date'] ?? transfer['time'];
                final time = dateVal != null ? DateFormat('hh:mm a').format(DateTime.parse(dateVal)) : '';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.swap_horiz, color: Colors.purple),
                    title: Text('من: ${transfer['from']} إلى: ${transfer['to']}'),
                    subtitle: Text('المبلغ: ${transfer['amount']} | رسوم: ${transfer['fee'] ?? 0} | $time'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          onPressed: () {
                            LoggerService.userAction('ضغط تعديل تحويل من السجل');
                            Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen(editTransferId: transfer['id'] ?? transfer['invoiceId']))).then((_) => setState(() {}));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteTransferPermanently(transfer['id'] ?? transfer['invoiceId']),
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
