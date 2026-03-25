import 'dart:io';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/services/logger_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/inventory_store.dart';
import '../../data/customer_store.dart';
import '../../data/day_records_store.dart';
import '../../data/draft_store.dart';
import '../../services/finance_service.dart';
import '../../services/pdf_service.dart';
import '../../state/day_state.dart';
import '../../state/cash_state.dart';
import '../../models/sale_item.dart';

class NewSaleScreen extends StatefulWidget {
  final String? editInvoiceId;
  const NewSaleScreen({super.key, this.editInvoiceId});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final customerController = TextEditingController();
  final itemController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final paidAmountController = TextEditingController();
  final discountController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _itemFocusNode = FocusNode();
  final _qtyFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _discountFocusNode = FocusNode();
  final _paidAmountFocusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();

  String paymentType = 'كاش';
  String? selectedWallet;
  bool _isSaving = false;
  String? originalInvoiceNumber;
  bool _isReturnMode = false;

  List<SaleItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  @override
  void initState() {
    super.initState();
    LoggerService.action('فتح شاشة البيع - ${widget.editInvoiceId != null ? 'تعديل فاتورة: ${widget.editInvoiceId}' : 'فاتورة جديدة'}');
    if (widget.editInvoiceId != null) {
      _loadInvoiceForEdit(widget.editInvoiceId!);
    } else {
      _loadDraft();
    }

    customerController.addListener(_saveDraft);
    paidAmountController.addListener(_saveDraft);
    discountController.addListener(_saveDraft);
  }

  void _loadInvoiceForEdit(String invoiceId) {
    final allRecords = DayRecordsStore.getAll();
    final invoiceRecords = allRecords.where((r) => r['invoiceId'] == invoiceId).toList();

    if (invoiceRecords.isNotEmpty) {
      final first = invoiceRecords.first;
      setState(() {
        customerController.text = first['customer'] ?? '';
        paymentType = (first['paymentType'] == 'نقدي' || first['paymentType'] == 'كاش') ? 'كاش' : first['paymentType'];
        final savedWallet = first['wallet'];
        selectedWallet = (savedWallet == 'نقدي' || savedWallet == '') ? null : savedWallet;
        discountController.text = (first['discount'] ?? 0).toString();
        paidAmountController.text = (first['paidAmount'] ?? 0).toString();
        originalInvoiceNumber = first['invoiceNumber']?.toString();

        items = invoiceRecords.map((e) => SaleItem(
          name: e['item'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
          isReturn: e['isReturn'] ?? false,
        )).toList();
      });
      LoggerService.logic('تم تحميل بيانات التعديل للفاتورة $invoiceId - عدد الأصناف: ${items.length}');
    }
  }

  void _loadDraft() {
    final draft = DraftStore.getSalesDraft();
    if (draft != null) {
      setState(() {
        customerController.text = draft['customer'] ?? '';
        paymentType = draft['paymentType'] ?? 'كاش';
        selectedWallet = (draft['wallet'] == 'نقدي') ? null : draft['wallet'];
        discountController.text = draft['discount'] ?? '0';
        paidAmountController.text = draft['paidAmount'] ?? '0';
        final List<dynamic> draftItems = draft['items'] ?? [];
        items = draftItems.map((e) => SaleItem(
          name: e['name'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
          isReturn: e['isReturn'] ?? false,
        )).toList();
      });
      LoggerService.info('تم استرجاع مسودة غير محفوظة للعميل: ${customerController.text}');
    } else {
      paidAmountController.text = '0';
      discountController.text = '0';
    }
  }

  void _saveDraft() {
    if (_isSaving || widget.editInvoiceId != null) return;
    DraftStore.saveSalesDraft(
      customer: customerController.text,
      paymentType: paymentType,
      wallet: selectedWallet,
      discount: discountController.text,
      paidAmount: paidAmountController.text,
      items: items.map((e) => {'name': e.name, 'qty': e.qty, 'price': e.price, 'isReturn': e.isReturn}).toList(),
    );
  }

  void _clearFullInvoice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text('هل تريد مسح فاتورة البيع الحالية والبدء من جديد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              LoggerService.action('ضغط زر مسح البيانات الحالية (Reset Form)');
              setState(() {
                items.clear();
                customerController.clear();
                itemController.clear();
                qtyController.clear();
                priceController.clear();
                paidAmountController.text = '0';
                discountController.text = '0';
                paymentType = 'كاش';
                selectedWallet = null;
                originalInvoiceNumber = null;
                _isReturnMode = false;
              });
              DraftStore.clearSalesDraft();
              Navigator.pop(context);
              ToastService.show('تم مسح الفاتورة بنجاح');
            },
            child: const Text('مسح الفاتورة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    customerController.removeListener(_saveDraft);
    paidAmountController.removeListener(_saveDraft);
    discountController.removeListener(_saveDraft);
    customerController.dispose();
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    discountController.dispose();
    _customerFocusNode.dispose();
    _itemFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    _discountFocusNode.dispose();
    _paidAmountFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = itemController.text.trim();
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;

    LoggerService.action('ضغط زر إضافة صنف: $name، كمية: $qty، سعر: $price، مرتجع: $_isReturnMode');

    if (name.isEmpty || qty <= 0 || price <= 0) {
      LoggerService.warn('فشل إضافة صنف: بيانات ناقصة أو غير صحيحة');
      ToastService.show('اكمل بيانات الصنف');
      return;
    }

    if (!_isReturnMode && widget.editInvoiceId == null) {
      final stockQty = InventoryStore.getItemQty(name);
      if (qty > stockQty) {
        LoggerService.warn('فشل إضافة صنف: الكمية المطلوبة ($qty) أكبر من المتاح ($stockQty)');
        ToastService.show('الكمية المتاحة في المخزن حالياً هي: $stockQty');
        return;
      }
    }

    setState(() {
      if (editingIndex != null) {
        items[editingIndex!] = SaleItem(name: name, qty: qty, price: price, isReturn: _isReturnMode);
        editingIndex = null;
      } else {
        items.add(SaleItem(name: name, qty: qty, price: price, isReturn: _isReturnMode));
      }
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      _isReturnMode = false; 
      _itemFocusNode.requestFocus();
    });
    _saveDraft();
  }

  String _calculateNewInvoiceNumber() {
    if (originalInvoiceNumber != null) return originalInvoiceNumber!;
    return DayRecordsStore.getNextInvoiceNumber('sale').toString();
  }

  Future<void> _saveSale() async {
    LoggerService.action('ضغط زر حفظ الفاتورة النهائي - إجمالي: $total');
    if (_isSaving) return;

    if (!context.read<DayState>().dayStarted) {
      LoggerService.warn('محاولة حفظ فاتورة واليوم لم يبدأ بعد');
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) {
      LoggerService.warn('محاولة حفظ فاتورة فارغة أو بدون اسم عميل');
      ToastService.show('اكمل بيانات الفاتورة');
      return;
    }

    final paidAmountValue = paymentType == 'آجل' ? 0.0 : double.tryParse(paidAmountController.text) ?? 0.0;

    if (paymentType != 'آجل' && paidAmountValue < total) {
      final diff = total - paidAmountValue;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تنبيه: المبلغ المدفوع أقل من الإجمالي'),
          content: Text('صافي الفاتورة: ${total.toStringAsFixed(2)}\nالمبلغ المدفوع: ${paidAmountValue.toStringAsFixed(2)}\nالعجز: ${diff.toStringAsFixed(2)}\n\nكيف تريد معالجة العجز؟'),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _performSave(paidAmountValue);
                  },
                  child: const Text('ترحيل الباقي لحساب العميل (آجل)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final currentDiscount = double.tryParse(discountController.text) ?? 0.0;
                    discountController.text = (currentDiscount + diff).toStringAsFixed(2);
                    setState(() {});
                    _performSave(paidAmountValue);
                  },
                  child: const Text('اعتبار العجز خصم إضافي'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _paidAmountFocusNode.requestFocus();
                  },
                  child: const Text('تعديل المبلغ المدفوع'),
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }

    _performSave(paidAmountValue);
  }

  Future<void> _generateAndShareInvoice(String invoiceNumber, double paidAmountValue, double dueAmount) async {
    try {
      final customerName = customerController.text.trim();
      final pdfData = await PdfService.generateInvoice(
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paidAmount: paidAmountValue,
        dueAmount: dueAmount,
        invoiceId: invoiceNumber,
        previousBalance: CustomerStore.getBalance(customerName) - dueAmount,
        newBalance: CustomerStore.getBalance(customerName),
        isPurchase: false,
      );

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'فاتورة_بيع_${customerName}_$dateStr.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة مبيعات رقم $invoiceNumber - $customerName');
    } catch (e) {
      LoggerService.error('خطأ أثناء توليد أو مشاركة الفاتورة', error: e);
      ToastService.show('حدث خطأ أثناء مشاركة الفاتورة');
    }
  }

  void _performSave(double paidAmountValue) async {
    setState(() => _isSaving = true);
    LoggerService.logic('بدء معالجة الحفظ: العميل: ${customerController.text}، المدفوع: $paidAmountValue');

    try {
      if (widget.editInvoiceId != null) {
        LoggerService.logic('وضع التعديل: عكس أثر الفاتورة القديمة ${widget.editInvoiceId}');
        DayRecordsStore.reverseInvoiceEffects(widget.editInvoiceId!);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      for (final item in items) {
        if (item.isReturn) {
          InventoryStore.returnItem(item.name, item.qty);
        } else {
          InventoryStore.sellItem(item.name, item.qty);
        }
      }

      CustomerStore.addCustomer(customerController.text.trim());
      final dueAmount = total - paidAmountValue;
      CustomerStore.updateBalance(customerController.text.trim(), dueAmount);

      if (paidAmountValue != 0) {
        if (paidAmountValue > 0) {
          FinanceService.deposit(amount: paidAmountValue, paymentType: paymentType, walletName: paymentType == 'تحويل' ? selectedWallet : null);
        } else {
          FinanceService.withdraw(amount: paidAmountValue.abs(), paymentType: paymentType, walletName: paymentType == 'تحويل' ? selectedWallet : null);
        }
      }

      final invoiceNumber = _calculateNewInvoiceNumber();
      const uuid = Uuid();
      final invoiceId = uuid.v4();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'sale',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customer': customerController.text.trim(),
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
          'isReturn': item.isReturn,
          'invoiceTotal': total,
          'paidAmount': paidAmountValue,
          'dueAmount': dueAmount,
          'paymentType': paymentType,
          'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
          'time': DateTime.now().toString(),
          'discount': discount,
        });
      }

      await _generateAndShareInvoice(invoiceNumber, paidAmountValue, dueAmount);

      LoggerService.info('تم حفظ الفاتورة بنجاح: رقم $invoiceNumber');
      DraftStore.clearSalesDraft();

      if (widget.editInvoiceId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          items.clear();
          customerController.clear();
          paidAmountController.text = '0';
          discountController.text = '0';
          paymentType = 'كاش';
          selectedWallet = null;
          _isReturnMode = false;
        });
        _customerFocusNode.requestFocus();
      }
      ToastService.show('تم حفظ الفاتورة بنجاح');
    } catch (e, stack) {
      LoggerService.error('خطأ قاتل أثناء حفظ الفاتورة', error: e, stackTrace: stack);
      ToastService.show('حدث خطأ أثناء الحفظ، يرجى مراجعة اللوج');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editInvoiceId != null ? 'تعديل فاتورة $originalInvoiceNumber' : 'فاتورة بيع جديدة'),
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
                onSelected: (v) { LoggerService.action('اختيار عميل: $v'); _itemFocusNode.requestFocus(); _saveDraft(); },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdownField(
                      focusNode: _itemFocusNode,
                      enabled: dayStarted && !_isSaving,
                      controller: itemController,
                      label: 'اسم الصنف',
                      onSearch: (value) => InventoryStore.getAllItems().where((e) => e['name'].toString().toLowerCase().contains(value.toLowerCase())).map((e) => "${e['name']} | (المتاح: ${e['quantity']})").toList(),
                      onSelected: (value) {
                        final name = value.split('|')[0].trim();
                        LoggerService.action('اختيار صنف: $name');
                        itemController.text = name;
                        final lastPrice = DayRecordsStore.getLastItemSalePrice(name);
                        if (lastPrice != null) priceController.text = lastPrice.toString();
                        _qtyFocusNode.requestFocus();
                      },
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: _isReturnMode ? Colors.orange.shade100 : Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [const Text('مرتجع'), Switch(value: _isReturnMode, onChanged: (v) { LoggerService.action('تغيير وضع المرتجع إلى: $v'); setState(() => _isReturnMode = v); }, activeColor: Colors.orange)]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SelectableTextField(enabled: dayStarted && !_isSaving, controller: qtyController, focusNode: _qtyFocusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), labelText: 'الكمية', onSubmitted: (_) => _priceFocusNode.requestFocus())),
                  const SizedBox(width: 12),
                  Expanded(child: SelectableTextField(enabled: dayStarted && !_isSaving, controller: priceController, focusNode: _priceFocusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), labelText: 'سعر الوحدة', onSubmitted: (_) => _addItem())),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: (dayStarted && !_isSaving) ? _addItem : null, child: Text(editingIndex != null ? 'تعديل البند' : 'إضافة للفاتورة')),
              const SizedBox(height: 20),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(color: item.isReturn ? Colors.orange.shade50 : null, child: ListTile(
                  onTap: (dayStarted && !_isSaving) ? () { setState(() { editingIndex = index; itemController.text = item.name; qtyController.text = item.qty.toString(); priceController.text = item.price.toString(); _isReturnMode = item.isReturn; _itemFocusNode.requestFocus(); }); } : null,
                  title: Text("${item.name} ${item.isReturn ? '(مرتجع)' : ''}"),
                  subtitle: Text('كمية: ${item.qty} | سعر: ${item.price} | إجمالي: ${item.total}'),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isSaving ? null : () { LoggerService.action('حذف صنف من القائمة: ${item.name}'); setState(() => items.removeAt(index)); _saveDraft(); }),
                ));
              }),
              const SizedBox(height: 20),
              Text('الإجمالي: ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SelectableTextField(enabled: dayStarted && !_isSaving, controller: discountController, focusNode: _discountFocusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), labelText: 'الخصم', onChanged: (_) => setState(() {}), onSubmitted: (_) => _paidAmountFocusNode.requestFocus()),
              const SizedBox(height: 12),
              Text('صافي الفاتورة: ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: paymentType,
                decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'كاش', child: Text('كاش')), DropdownMenuItem(value: 'تحويل', child: Text('تحويل')), DropdownMenuItem(value: 'آجل', child: Text('آجل'))],
                onChanged: (dayStarted && !_isSaving) ? (value) { LoggerService.action('تغيير طريقة الدفع إلى: $value'); setState(() { paymentType = value!; if (paymentType != 'تحويل') selectedWallet = null; if (paymentType != 'آجل') _paidAmountFocusNode.requestFocus(); }); _saveDraft(); } : null,
              ),
              if (paymentType == 'تحويل') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: (selectedWallet != null && wallets.contains(selectedWallet)) ? selectedWallet : null,
                  decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                  items: wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (dayStarted && !_isSaving) ? (v) { LoggerService.action('اختيار محفظة التحويل: $v'); setState(() => selectedWallet = v); _saveDraft(); } : null,
                ),
              ],
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                SelectableTextField(enabled: dayStarted && !_isSaving, controller: paidAmountController, focusNode: _paidAmountFocusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), labelText: 'المبلغ المدفوع', onSubmitted: (_) => _saveSale()),
              ],
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: (dayStarted && !_isSaving) ? _saveSale : null, child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ وإرسال الفاتورة'))),
            ],
          ),
        ),
      ),
    );
  }
}
