import 'dart:io';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:aimex/services/toast_service.dart';
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
  State<SettlementScreen> createState() =>
      _SettlementScreenState();
}

class _SettlementScreenState
    extends State<SettlementScreen> {

  final customerController = TextEditingController();
  final amountController = TextEditingController();

  String paymentType = 'كاش';
  String? selectedWallet;
  final _customerFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editSettlementId != null) {
      _loadSettlementForEdit(widget.editSettlementId!);
    }
  }

  void _loadSettlementForEdit(String id) {
    final record = DayRecordsStore.getAll().firstWhere((r) => r['id'] == id || r['invoiceId'] == id);
    setState(() {
      customerController.text = record['customer'] ?? '';
      amountController.text = (record['amount'] ?? 0).toString();
      paymentType = record['paymentType'] ?? 'كاش';
      selectedWallet = record['wallet'] == 'نقدي' ? null : record['wallet'];
    });
  }

  void _deleteSettlementPermanently(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عملية التحصيل نهائياً؟'),
        content: const Text('سيتم إعادة المديونية للعميل وخصم المبلغ من الخزنة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context); 
              if (widget.editSettlementId != null) Navigator.pop(context);
              setState(() {});
              ToastService.show('تم حذف التحصيل وعكس أثرها');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    customerController.dispose();
    amountController.dispose();
    _customerFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
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
      final fileName = '$customerName $dateStr.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'إيصال سداد - $customerName');
    } catch (e) {
      ToastService.show('حدث خطأ أثناء مشاركة الإيصال');
    }
  }

  Future<void> _saveSettlement() async {
    if (!DayState.instance.dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final customer = customerController.text.trim();
    final amount = double.tryParse(amountController.text) ?? 0;

    if (customer.isEmpty || amount <= 0) {
      ToastService.show('ادخل اسم عميل ومبلغ صحيح');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.editSettlementId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editSettlementId!);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final result = FinanceService.deposit(
        amount: amount,
        paymentType: paymentType,
        walletName: paymentType == 'تحويل' ? selectedWallet : null,
      );

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
      });

      await _generateAndShareSettlement(customer, amount);

      ToastService.show(widget.editSettlementId != null ? 'تم تعديل التحصيل بنجاح' : 'تم تسجيل التحصيل وتحديث حساب العميل');

      if (widget.editSettlementId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          amountController.clear();
          customerController.clear();
          selectedWallet = null;
          _isSaving = false;
        });
        _customerFocusNode.requestFocus();
      }
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final todaySettlements = DayRecordsStore.getAll()
        .where((r) => r['type'] == 'settlement')
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editSettlementId != null ? 'تعديل تحصيل' : 'سداد العملاء'),
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
                  onSelected: (_) => _amountFocusNode.requestFocus(),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: !_isSaving,
                  controller: amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveSettlement(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentType,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                    DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                  ],
                  onChanged: _isSaving ? null : (value) => setState(() => paymentType = value!),
                ),
                if (paymentType == 'تحويل') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedWallet,
                    decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                    items: wallets.map((wallet) => DropdownMenuItem(value: wallet, child: Text(wallet))).toList(),
                    onChanged: _isSaving ? null : (value) => setState(() => selectedWallet = value),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettlement,
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ عملية السداد'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('سجل تحصيلات اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_add, color: Colors.teal),
                    title: Text('${settlement['customer']}'),
                    subtitle: Text('المبلغ: ${settlement['amount']} | ${settlement['paymentType']} | $time'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.teal, size: 20),
                          onPressed: () => _generateAndShareSettlement(settlement['customer'], (settlement['amount'] as num).toDouble()),
                        ),
                        if (!isBeingEdited)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettlementScreen(editSettlementId: settlement['id'] ?? settlement['invoiceId']))).then((_) => setState(() {})),
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
