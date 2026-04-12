import 'dart:io';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../services/finance_service.dart';
import '../services/pdf_service.dart';
import '../data/day_records_store.dart';
import '../data/customer_store.dart';

class SettlementScreen extends StatefulWidget {
  final String? editSettlementId;
  const SettlementScreen({super.key, this.editSettlementId});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final customerController = TextEditingController();
  final amountController = TextEditingController();
  final remarksController = TextEditingController();

  String paymentType = 'كاش';
  String? selectedWallet;
  final _customerFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _remarksFocusNode = FocusNode();
  bool _isSaving = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.editSettlementId != null) {
      _loadSettlementForEdit(widget.editSettlementId!);
    }
    customerController.addListener(_updateBalance);
  }

  void _updateBalance() {
    final name = customerController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _currentBalance = CustomerStore.getBalance(name);
      });
    } else {
      setState(() {
        _currentBalance = 0.0;
      });
    }
  }

  void _loadSettlementForEdit(String id) {
    try {
      final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
      setState(() {
        customerController.text = record['customer'] ?? '';
        amountController.text = (record['amount'] ?? 0).toString();
        paymentType = record['paymentType'] ?? 'كاش';
        selectedWallet = record['wallet'] == 'نقدي' ? null : record['wallet'];
        remarksController.text = record['remarks'] ?? '';
      });
    } catch (e) {
      LoggerService.error('فشل تحميل بيانات التحصيل للتعديل', error: e);
    }
  }

  void _deleteSettlementPermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عملية التحصيل نهائياً؟'),
        content: const Text('سيتم حذف السجل وعكس أثره من الخزنة وحساب العميل. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              LoggerService.userAction('حذف تحصيل نهائياً', {'id': id});
              DayRecordsStore.reverseInvoiceEffects(id);
              if (widget.editSettlementId != null) {
                Navigator.pop(context);
                Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
              setState(() {});
              ToastService.show('تم حذف التحصيل وعكس أثره');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShareSettlement(String customerName, double amount) async {
    try {
      final pdfData = await PdfService.generateInvoice(
        customerName: customerName,
        items: [],
        subtotal: 0,
        discount: 0,
        total: 0,
        paidAmount: amount,
        dueAmount: 0,
        invoiceId: 'S-',
        previousBalance: CustomerStore.getBalance(customerName) + amount,
        newBalance: CustomerStore.getBalance(customerName),
        isSettlement: true,
      );

      final dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
      final fileName = '${customerName}_$dateStr.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'إيصال سداد - $customerName');
    } catch (e) {
      LoggerService.error('خطأ أثناء توليد أو مشاركة إيصال السداد', error: e);
    }
  }

  Future<void> _saveSettlement() async {
    if (!DayState.instance.dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final customer = customerController.text.trim();
    final amount = double.tryParse(amountController.text) ?? 0;
    final remarks = remarksController.text.trim();

    if (customer.isEmpty || amount == 0) {
      ToastService.show('ادخل اسم عميل ومبلغ صحيح');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.editSettlementId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editSettlementId!);
      }

      // تم تعديل دوال المالية لدعم المبالغ السالبة تلقائياً
      // إذا كان المبلغ موجب: إيداع في الخزنة (تحصيل من عميل)
      // إذا كان المبلغ سالب: سحب من الخزنة (رد مبلغ لعميل)
      FinanceResult result;
      if (amount > 0) {
        result = FinanceService.deposit(
          amount: amount,
          paymentType: paymentType,
          walletName: paymentType == 'تحويل' ? selectedWallet : null,
          reason: "تحصيل من عميل: $customer"
        );
      } else {
        result = FinanceService.withdraw(
          amount: amount.abs(),
          paymentType: paymentType,
          walletName: paymentType == 'تحويل' ? selectedWallet : null,
          reason: "رد مبلغ لعميل: $customer",
          allowNegative: true, // سماح بالسالب في حالة رد مبالغ
        );
      }

      if (!result.success) {
        ToastService.show(result.message);
        setState(() => _isSaving = false);
        return;
      }

      CustomerStore.addCustomer(customer);
      CustomerStore.updateBalance(customer, -amount);

      const uuid = Uuid();
      final id = uuid.v4();

      DayRecordsStore.addRecord({
        'id': id,
        'type': 'settlement',
        'customer': customer,
        'amount': amount,
        'paymentType': paymentType,
        'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
        'date': DateTime.now().toString(),
        'remarks': remarks,
      });

      await _generateAndShareSettlement(customer, amount);

      ToastService.show(widget.editSettlementId != null ? 'تم تعديل العملية بنجاح' : 'تم تسجيل العملية وتحديث حساب العميل');

      if (widget.editSettlementId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          customerController.clear();
          remarksController.clear();
          selectedWallet = null;
          _isSaving = false;
        });
        _customerFocusNode.requestFocus();
      }
    } catch (e, stack) {
      LoggerService.error('خطأ قاتل أثناء حفظ العملية', error: e, stackTrace: stack);
      ToastService.show('حدث خطأ أثناء الحفظ');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final allRecords = DayRecordsStore.getAll();
    
    final todaySettlements = allRecords.where((r) {
      if (r['type'] != 'settlement') return false;
      
      if (r['invoiceId'] != null) {
        final saleRecord = allRecords.firstWhere(
          (e) => e['type'] == 'sale' && e['invoiceId'] == r['invoiceId'],
          orElse: () => {},
        );
        if (saleRecord.isNotEmpty) {
          final pAmt = (saleRecord['paidAmount'] as num).toDouble();
          if (pAmt == 0) return false;
        }
      }
      return true;
    }).toList().reversed.toList();

    String balanceText = "";
    if (customerController.text.trim().isNotEmpty) {
      if (_currentBalance > 0) {
        balanceText = " (عليه: ${_currentBalance.toStringAsFixed(2)})";
      } else if (_currentBalance < 0) {
        balanceText = " (له: ${_currentBalance.abs().toStringAsFixed(2)})";
      } else {
        balanceText = " (رصيده صفر)";
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.editSettlementId != null ? "تعديل عملية" : "سداد العملاء"}$balanceText'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SearchableDropdownField(
                  enabled: !_isSaving,
                  focusNode: _customerFocusNode,
                  controller: customerController,
                  label: 'اسم العميل',
                  onSearch: (value) => CustomerStore.searchCustomers(value),
                  onSelected: (v) {
                    LoggerService.userAction('اختيار عميل في التحصيل', {'اسم': v});
                    _amountFocusNode.requestFocus();
                  },
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
                  value: paymentType,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                    DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                  ],
                  onChanged: _isSaving ? null : (value) {
                    setState(() => paymentType = value!);
                    LoggerService.userAction('تغيير طريقة الدفع', {'النوع': value});
                  },
                ),
                if (paymentType == 'تحويل') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedWallet,
                    decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                    items: wallets.map((wallet) => DropdownMenuItem(value: wallet, child: Text(wallet))).toList(),
                    onChanged: _isSaving ? null : (value) {
                      setState(() => selectedWallet = value);
                      LoggerService.userAction('اختيار محفظة', {'المحفظة': value});
                    },
                  ),
                ],
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
            child: Text('سجل حركات السداد اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todaySettlements.length,
              itemBuilder: (context, index) {
                final settlement = todaySettlements[index];
                final dateValue = settlement['date'] ?? settlement['time'];
                final time = dateValue != null ? DateFormat('hh:mm a').format(DateTime.parse(dateValue)) : '';
                final bool isBeingEdited = widget.editSettlementId != null && 
                    (settlement['id'] == widget.editSettlementId || settlement['invoiceId'] == widget.editSettlementId);
                final remarks = settlement['remarks'] ?? '';
                final amt = (settlement['amount'] as num).toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      amt > 0 ? Icons.person_add : Icons.person_remove,
                      color: amt > 0 ? Colors.teal : Colors.orange,
                    ),
                    title: Text('${settlement['customer']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المبلغ: $amt | ${settlement['paymentType']} | $time'),
                        if (remarks.isNotEmpty)
                          Text('ملاحظة: $remarks', style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.teal, size: 20),
                          onPressed: () {
                            LoggerService.userAction('مشاركة إيصال من السجل');
                            _generateAndShareSettlement(settlement['customer'], (settlement['amount'] as num).toDouble());
                          },
                        ),
                        if (!isBeingEdited)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () {
                              LoggerService.userAction('ضغط تعديل من السجل');
                              Navigator.push(context, MaterialPageRoute(builder: (_) => SettlementScreen(editSettlementId: settlement['id'] ?? settlement['invoiceId']))).then((_) => setState(() {}));
                            },
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
