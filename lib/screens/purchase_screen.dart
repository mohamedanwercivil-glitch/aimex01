import 'dart:io';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/inventory_store.dart';
import '../data/supplier_store.dart';
import '../data/day_records_store.dart';
import '../data/draft_store.dart';
import '../../services/finance_service.dart';
import '../../services/pdf_service.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../models/sale_item.dart';
import '../utils/arabic_utils.dart';

class PurchaseItem {
  final String name;
  final double qty;
  final double price;
  final bool isReturn;

  PurchaseItem({
    required this.name,
    required this.qty,
    required this.price,
    this.isReturn = false,
  });

  double get total => isReturn ? -(qty * price) : (qty * price);
}

class PurchaseScreen extends StatefulWidget {
  final String? editInvoiceId;
  const PurchaseScreen({super.key, this.editInvoiceId});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final supplierController = TextEditingController();
  final itemController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final paidAmountController = TextEditingController();
  final discountController = TextEditingController();
  final _supplierFocusNode = FocusNode();
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

  List<PurchaseItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  @override
  void initState() {
    super.initState();
    if (widget.editInvoiceId != null) {
      _loadInvoiceForEdit(widget.editInvoiceId!);
    } else {
      _loadDraft();
    }

    supplierController.addListener(_saveDraft);
    paidAmountController.addListener(_saveDraft);
    discountController.addListener(_saveDraft);
  }

  void _loadInvoiceForEdit(String invoiceId) {
    final allRecords = DayRecordsStore.getAll();
    final invoiceRecords = allRecords.where((r) => r['invoiceId'] == invoiceId).toList();

    if (invoiceRecords.isNotEmpty) {
      final first = invoiceRecords.first;
      setState(() {
        supplierController.text = first['supplier'] ?? '';
        paymentType = (first['paymentType'] == 'نقدي' || first['paymentType'] == 'كاش') ? 'كاش' : (first['paymentType'] ?? 'كاش');

        final savedWallet = first['wallet'];
        selectedWallet = (savedWallet == 'نقدي' || savedWallet == '' || savedWallet == null) ? null : savedWallet;

        discountController.text = (first['discount'] ?? 0).toString();
        paidAmountController.text = (first['paidAmount'] ?? 0).toString();
        originalInvoiceNumber = first['invoiceNumber']?.toString();

        items = invoiceRecords.map((e) => PurchaseItem(
          name: e['item'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
          isReturn: e['isReturn'] ?? false,
        )).toList();
      });
    }
  }

  void _loadDraft() {
    final draft = DraftStore.getPurchasesDraft();
    if (draft != null) {
      setState(() {
        supplierController.text = draft['supplier'] ?? '';
        paymentType = draft['paymentType'] ?? 'كاش';
        selectedWallet = (draft['wallet'] == 'نقدي' || draft['wallet'] == null) ? null : draft['wallet'];
        discountController.text = draft['discount'] ?? '0';
        paidAmountController.text = draft['paidAmount'] ?? '0';
        final List<dynamic> draftItems = draft['items'] ?? [];
        items = draftItems.map((e) => PurchaseItem(
          name: e['name'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
          isReturn: e['isReturn'] ?? false,
        )).toList();
      });
    } else {
      paidAmountController.text = '0';
      discountController.text = '0';
    }
  }

  void _saveDraft() {
    if (_isSaving || widget.editInvoiceId != null) return;
    DraftStore.savePurchasesDraft(
      supplier: supplierController.text,
      paymentType: paymentType,
      wallet: selectedWallet,
      discount: discountController.text,
      paidAmount: paidAmountController.text,
      items: items.map((e) => {'name': e.name, 'qty': e.qty, 'price': e.price, 'isReturn': e.isReturn}).toList(),
    );
  }

  void _deleteFullInvoicePermanently() {
    if (widget.editInvoiceId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فاتورة المشتريات نهائياً؟'),
        content: const Text('سيتم إلغاء أثر الفاتورة بالكامل من المخزن وحساب المورد والخزنة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(widget.editInvoiceId!);
              Navigator.pop(context);
              Navigator.pop(context);
              ToastService.show('تم حذف الفاتورة وعكس أثرها بالكامل');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearFullInvoice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text('هل تريد مسح فاتورة المشتريات الحالية والبدء من جديد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              setState(() {
                items.clear();
                supplierController.clear();
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
              DraftStore.clearPurchasesDraft();
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
    supplierController.removeListener(_saveDraft);
    paidAmountController.removeListener(_saveDraft);
    discountController.removeListener(_saveDraft);
    supplierController.dispose();
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    discountController.dispose();
    _supplierFocusNode.dispose();
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

    if (name.isEmpty || qty <= 0 || price <= 0) {
      ToastService.show('اكمل بيانات الصنف');
      return;
    }

    if (_isReturnMode && widget.editInvoiceId == null) {
      final stockQty = InventoryStore.getItemQty(name);
      if (qty > stockQty) {
        ToastService.show('الكمية المتاحة في المخزن حالياً هي: $stockQty');
        return;
      }
    }

    final existingIndex = items.indexWhere((item) => item.name == name && item.isReturn == _isReturnMode);
    if (existingIndex != -1 && existingIndex != editingIndex) {
      ToastService.show('هذا البند موجود بالفعل في الفاتورة بنفس الحالة');
      return;
    }

    setState(() {
      if (editingIndex != null) {
        items[editingIndex!] = PurchaseItem(name: name, qty: qty, price: price, isReturn: _isReturnMode);
        editingIndex = null;
      } else {
        items.add(PurchaseItem(name: name, qty: qty, price: price, isReturn: _isReturnMode));
      }
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      _isReturnMode = false;
      _itemFocusNode.requestFocus();
    });
    _saveDraft();
  }

  Future<void> _saveInvoice() async {
    if (_isSaving) return;

    if (!context.read<DayState>().dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final supplier = supplierController.text.trim();
    if (supplier.isEmpty || items.isEmpty) {
      ToastService.show('اكمل بيانات الفاتورة');
      return;
    }

    if (paymentType == 'تحويل' && selectedWallet == null) {
      ToastService.show('يجب اختيار المحفظة عند اختيار دفع تحويل');
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
                  child: const Text('ترحيل الباقي لحساب المورد (آجل)'),
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

  void _performSave(double paidAmountValue) async {
    setState(() => _isSaving = true);

    try {
      if (widget.editInvoiceId != null) {
        DayRecordsStore.reverseInvoiceEffects(widget.editInvoiceId!);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      for (final item in items) {
        if (item.isReturn) InventoryStore.sellItem(item.name, item.qty);
        else InventoryStore.addItem(item.name, item.qty, item.price);
      }

      SupplierStore.addSupplier(supplierController.text.trim());
      final dueAmount = total - paidAmountValue;
      SupplierStore.updateBalance(supplierController.text.trim(), dueAmount);

      if (paidAmountValue != 0) {
        if (paidAmountValue > 0) FinanceService.withdraw(amount: paidAmountValue, paymentType: paymentType, walletName: selectedWallet);
        else FinanceService.deposit(amount: paidAmountValue.abs(), paymentType: paymentType, walletName: selectedWallet);
      }

      final invoiceNumber = originalInvoiceNumber ?? DayRecordsStore.getNextInvoiceNumber('purchase').toString();
      const uuid = Uuid();
      final invoiceId = uuid.v4();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'purchase',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'supplier': supplierController.text.trim(),
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
          'isReturn': item.isReturn,
          'invoiceTotal': total,
          'paymentType': paymentType,
          'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
          'paidAmount': paidAmountValue,
          'dueAmount': dueAmount,
          'time': DateTime.now().toString(),
          'discount': discount,
        });
      }

      DraftStore.clearPurchasesDraft();

      if (widget.editInvoiceId != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          items.clear();
          supplierController.clear();
          itemController.clear();
          qtyController.clear();
          priceController.clear();
          paidAmountController.text = '0';
          discountController.text = '0';
          editingIndex = null;
          selectedWallet = null;
          paymentType = 'كاش';
          _isReturnMode = false;
        });
        _supplierFocusNode.requestFocus();
      }
      ToastService.show('تم حفظ الفاتورة بنجاح');
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
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
        title: Text(widget.editInvoiceId != null ? 'تعديل فاتورة $originalInvoiceNumber' : 'فاتورة شراء جديدة'),
        actions: [
          if (widget.editInvoiceId != null)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
              onPressed: _isSaving ? null : _deleteFullInvoicePermanently,
              tooltip: 'حذف الفاتورة بالكامل',
            ),
          if (widget.editInvoiceId == null)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _isSaving ? null : _clearFullInvoice,
              tooltip: 'مسح الفاتورة الحالية',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SearchableDropdownField(
              focusNode: _supplierFocusNode,
              enabled: dayStarted && !_isSaving,
              controller: supplierController,
              label: 'اسم المورد',
              onSearch: (value) {
                final query = ArabicUtils.normalize(value);
                return SupplierStore.getAllSuppliers()
                    .where((name) => ArabicUtils.normalize(name).contains(query))
                    .toList();
              },
              onSelected: (_) { _itemFocusNode.requestFocus(); _saveDraft(); },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SearchableDropdownField(
                    enabled: dayStarted && !_isSaving,
                    controller: itemController,
                    focusNode: _itemFocusNode,
                    label: 'اسم الصنف',
                    onSearch: (value) {
                      final query = ArabicUtils.normalize(value);
                      final results = InventoryStore.getAllItems()
                          .where((e) => ArabicUtils.normalize(e['name'] as String).contains(query))
                          .toList();

                      return results.map((e) {
                        final name = e['name'] as String;
                        final lastPrice = (e['lastBuyPrice'] as num?)?.toDouble() ??
                            (e['avgBuyPrice'] as num?)?.toDouble() ?? 0.0;
                        final qty = e['quantity'] ?? 0;

                        return "$name | السعر: $lastPrice | (المتاح: $qty)";
                      }).toList();
                    },
                    onSelected: (value) {
                      final parts = value.split('|');
                      itemController.text = parts[0].trim();
                      _qtyFocusNode.requestFocus();
                    },
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _qtyFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: _isReturnMode ? Colors.orange.shade100 : Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [const Text('مرتجع'), Switch(value: _isReturnMode, onChanged: (v) => setState(() => _isReturnMode = v), activeThumbColor: Colors.orange)]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableTextField(
                    enabled: dayStarted && !_isSaving,
                    controller: qtyController,
                    focusNode: _qtyFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    labelText: 'الكمية',
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_priceFocusNode),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableTextField(
                    enabled: dayStarted && !_isSaving,
                    controller: priceController,
                    focusNode: _priceFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    labelText: 'سعر الشراء',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: (dayStarted && !_isSaving) ? _addItem : null, child: Text(editingIndex != null ? 'تعديل البند' : 'إضافة للقائمة')),
            const SizedBox(height: 20),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Card(
                color: item.isReturn ? Colors.orange.shade50 : null,
                child: ListTile(
                  onTap: (dayStarted && !_isSaving) ? () {
                    setState(() { editingIndex = index; itemController.text = item.name; qtyController.text = item.qty.toString(); priceController.text = item.price.toString(); _isReturnMode = item.isReturn; _itemFocusNode.requestFocus(); });
                  } : null,
                  title: Text("${item.name} ${item.isReturn ? '(مرتجع)' : ''}"),
                  subtitle: Text('كمية: ${item.qty}  سعر: ${item.price}  إجمالي: ${item.total}'),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isSaving ? null : () { setState(() => items.removeAt(index)); _saveDraft(); }),
                ),
              );
            }),
            const SizedBox(height: 20),
            Text('الإجمالي: ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SelectableTextField(
              enabled: dayStarted && !_isSaving,
              controller: discountController,
              focusNode: _discountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              labelText: 'الخصم',
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) { if (paymentType != 'آجل') FocusScope.of(context).requestFocus(_paidAmountFocusNode); },
            ),
            const SizedBox(height: 12),
            Text('صافي الفاتورة: ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: paymentType,
              decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
              items: const [DropdownMenuItem(value: 'كاش', child: Text('كاش')), DropdownMenuItem(value: 'تحويل', child: Text('تحويل')), DropdownMenuItem(value: 'آجل', child: Text('آجل'))],
              onChanged: (dayStarted && !_isSaving) ? (value) {
                setState(() {
                  if (value != 'تحويل') selectedWallet = null;
                  paymentType = value!;
                  if (paymentType != 'آجل') FocusScope.of(context).requestFocus(_paidAmountFocusNode);
                });
                _saveDraft();
              } : null,
            ),
            if (paymentType == 'تحويل') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: (selectedWallet != null && wallets.contains(selectedWallet)) ? selectedWallet : null,
                decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                items: wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: (dayStarted && !_isSaving) ? (v) { setState(() => selectedWallet = v); _saveDraft(); } : null,
              ),
            ],
            if (paymentType != 'آجل') ...[
              const SizedBox(height: 12),
              SelectableTextField(enabled: dayStarted && !_isSaving, controller: paidAmountController, focusNode: _paidAmountFocusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), labelText: 'المبلغ المدفوع', textInputAction: TextInputAction.done, onSubmitted: (_) => _saveInvoice()),
            ],
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: (dayStarted && !_isSaving) ? _saveInvoice : null, child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الفاتورة'))),
          ],
        ),
      ),
    );
  }
}
