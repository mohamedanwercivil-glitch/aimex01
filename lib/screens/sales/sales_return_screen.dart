import 'dart:io';
import 'package:aimex/services/pdf_service.dart';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../data/inventory_store.dart';
import '../../data/customer_store.dart';
import '../../data/day_records_store.dart';
import '../../services/finance_service.dart';
import '../../state/day_state.dart';
import '../../state/cash_state.dart';
import '../../models/sale_item.dart';

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final customerController = TextEditingController();
  final itemController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final refundAmountController = TextEditingController();

  final _customerFocusNode = FocusNode();
  final _itemFocusNode = FocusNode();
  final _qtyFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _refundAmountFocusNode = FocusNode();

  String refundType = 'خصم من الحساب'; // 'خصم من الحساب' or 'كاش' or 'تحويل'
  String? selectedWallet;
  bool _isSaving = false;

  List<SaleItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    refundAmountController.text = '0';
  }

  @override
  void dispose() {
    customerController.dispose();
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    refundAmountController.dispose();
    _customerFocusNode.dispose();
    _itemFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    _refundAmountFocusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = itemController.text.trim();
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;

    if (name.isEmpty || qty <= 0 || price <= 0) {
      ToastService.show('اكمل بيانات الصنف');
      return;
    }

    setState(() {
      if (editingIndex != null) {
        items[editingIndex!] = SaleItem(name: name, qty: qty, price: price);
        editingIndex = null;
      } else {
        items.add(SaleItem(name: name, qty: qty, price: price));
      }
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      _itemFocusNode.requestFocus();
    });
  }

  Future<void> _saveReturn() async {
    if (_isSaving) return;

    if (!context.read<DayState>().dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) {
      ToastService.show('اكمل بيانات المرتجع');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final refundAmountValue = double.tryParse(refundAmountController.text) ?? 0.0;

      final previousBalance = CustomerStore.getBalance(customer);

      // تحديث المخزن
      for (final item in items) {
        InventoryStore.returnItem(item.name, item.qty);
      }

      // تحديث حساب العميل
      final netCreditToCustomer = subtotal - refundAmountValue;
      CustomerStore.updateBalance(customer, -netCreditToCustomer);

      final newBalance = CustomerStore.getBalance(customer);

      // إذا تم رد مبلغ مالي للعميل (كاش أو تحويل)
      if (refundAmountValue > 0) {
        FinanceService.withdraw(
          amount: refundAmountValue,
          paymentType: refundType == 'تحويل' ? 'تحويل' : 'كاش',
          walletName: refundType == 'تحويل' ? selectedWallet : null,
        );
      }

      final invoiceNumber = DayRecordsStore.getNextInvoiceNumber('sales_return').toString();
      const uuid = Uuid();
      final invoiceId = uuid.v4();
      final now = DateTime.now().toString();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'sales_return',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customer': customer,
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
          'invoiceTotal': subtotal,
          'refundAmount': refundAmountValue,
          'refundType': refundType,
          'wallet': refundType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
          'time': now,
        });
      }

      ToastService.show('تم حفظ المرتجع بنجاح');

      await _generateAndSharePdf(
        customerName: customer,
        invoiceId: invoiceNumber,
        refundAmount: refundAmountValue,
        previousBalance: previousBalance,
        newBalance: newBalance,
      );

      setState(() {
        items.clear();
        customerController.clear();
        itemController.clear();
        qtyController.clear();
        priceController.clear();
        refundAmountController.text = '0';
        refundType = 'خصم من الحساب';
        selectedWallet = null;
        editingIndex = null;
      });

      _customerFocusNode.requestFocus();
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAndSharePdf({
    required String customerName,
    required String invoiceId,
    required double refundAmount,
    required double previousBalance,
    required double newBalance,
  }) async {
    final pdfData = await PdfService.generateInvoice(
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      discount: 0,
      total: subtotal,
      paidAmount: refundAmount,
      dueAmount: subtotal - refundAmount,
      invoiceId: "R-$invoiceId",
      previousBalance: previousBalance,
      newBalance: newBalance,
    );

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/return_$invoiceId.pdf');
    await tempFile.writeAsBytes(pdfData);

    await Share.shareXFiles(
      [XFile(tempFile.path)],
      text: 'إيصال مرتجع مبيعات رقم $invoiceId للعميل: $customerName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مرتجع مبيعات من عميل'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SearchableDropdownField(
                focusNode: _customerFocusNode,
                enabled: dayStarted && !_isSaving,
                controller: customerController,
                label: 'اسم العميل',
                onSearch: (value) => CustomerStore.searchCustomers(value),
                onSelected: (_) => _itemFocusNode.requestFocus(),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SearchableDropdownField(
                focusNode: _itemFocusNode,
                enabled: dayStarted && !_isSaving,
                controller: itemController,
                label: 'اسم الصنف المرتجع',
                onSearch: (value) => InventoryStore.getAllItems()
                    .where((item) => item['name'].toString().toLowerCase().contains(value.toLowerCase()))
                    .map((e) => "${e['name']} | (المخزن: ${e['quantity']})")
                    .toList(),
                onSelected: (value) {
                  final name = value.split('|')[0].trim();
                  itemController.text = name;
                  _qtyFocusNode.requestFocus();
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted && !_isSaving,
                controller: qtyController,
                focusNode: _qtyFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                labelText: 'الكمية المرتجعة',
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocusNode.requestFocus(),
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted && !_isSaving,
                controller: priceController,
                focusNode: _priceFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                labelText: 'سعر الوحدة في المرتجع',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: (dayStarted && !_isSaving) ? _addItem : null,
                icon: const Icon(Icons.add),
                label: Text(editingIndex != null ? 'تعديل البند' : 'إضافة للقائمة'),
              ),
              const SizedBox(height: 20),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  child: ListTile(
                    onTap: (dayStarted && !_isSaving) ? () {
                      setState(() {
                        editingIndex = index;
                        itemController.text = item.name;
                        qtyController.text = item.qty.toString();
                        priceController.text = item.price.toString();
                        _itemFocusNode.requestFocus();
                      });
                    } : null,
                    title: Text(item.name),
                    subtitle: Text('كمية: ${item.qty} | سعر: ${item.price} | إجمالي: ${item.total}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isSaving ? null : () => setState(() => items.removeAt(index)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Text('إجمالي المرتجع: ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: refundType,
                decoration: const InputDecoration(labelText: 'طريقة المعالجة المالية', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'خصم من الحساب', child: Text('خصم من مديونية العميل')),
                  DropdownMenuItem(value: 'كاش', child: Text('رد المبلغ نقداً (كاش)')),
                  DropdownMenuItem(value: 'تحويل', child: Text('رد المبلغ (تحويل)')),
                ],
                onChanged: (dayStarted && !_isSaving) ? (value) {
                  setState(() {
                    refundType = value!;
                    if (refundType == 'خصم من الحساب') {
                      refundAmountController.text = '0';
                    } else {
                      refundAmountController.text = subtotal.toString();
                    }
                  });
                } : null,
              ),
              if (refundType != 'خصم من الحساب') ...[
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted && !_isSaving,
                  controller: refundAmountController,
                  focusNode: _refundAmountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ المدفوع للعميل فعلياً',
                  textInputAction: TextInputAction.done,
                ),
              ],
              if (refundType == 'تحويل') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWallet,
                  decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                  items: wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (dayStarted && !_isSaving) ? (v) => setState(() => selectedWallet = v) : null,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                  onPressed: (dayStarted && !_isSaving) ? _saveReturn : null,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ المرتجع'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
