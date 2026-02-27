// ignore_for_file: deprecated_member_use

import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/inventory_store.dart';
import '../data/supplier_store.dart';
import '../data/day_records_store.dart';
import '../data/draft_store.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';

class PurchaseItem {
  final String name;
  final double qty;
  final double price;

  PurchaseItem({
    required this.name,
    required this.qty,
    required this.price,
  });

  double get total => qty * price;
}

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

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
  final Map<String, GlobalKey> _itemKeys = {};

  String paymentType = 'كاش';
  String? selectedWallet;
  bool _isSaving = false;

  List<PurchaseItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    
    supplierController.addListener(_saveDraft);
    paidAmountController.addListener(_saveDraft);
    discountController.addListener(_saveDraft);
  }

  void _loadDraft() {
    final draft = DraftStore.getPurchasesDraft();
    if (draft != null) {
      setState(() {
        supplierController.text = draft['supplier'] ?? '';
        paymentType = draft['paymentType'] ?? 'كاش';
        selectedWallet = draft['wallet'];
        discountController.text = draft['discount'] ?? '0';
        paidAmountController.text = draft['paidAmount'] ?? '0';
        final List<dynamic> draftItems = draft['items'] ?? [];
        items = draftItems.map((e) => PurchaseItem(
          name: e['name'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
        )).toList();
      });
    } else {
      paidAmountController.text = '0';
      discountController.text = '0';
    }
  }

  void _saveDraft() {
    if (_isSaving) return;
    DraftStore.savePurchasesDraft(
      supplier: supplierController.text,
      paymentType: paymentType,
      wallet: selectedWallet,
      discount: discountController.text,
      paidAmount: paidAmountController.text,
      items: items,
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

  void _scrollToItem(String itemName) {
    final key = _itemKeys[itemName];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addItem() {
    final name = itemController.text.trim();
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;

    if (name.isEmpty || qty <= 0 || price <= 0) {
      ToastService.show('اكمل بيانات الصنف');
      return;
    }

    final existingIndex = items.indexWhere((item) => item.name == name);
    if (existingIndex != -1 && existingIndex != editingIndex) {
      ToastService.show('هذا البند موجود بالفعل في الفاتورة');
      _scrollToItem(name);
      return;
    }

    setState(() {
      if (editingIndex != null) {
        items[editingIndex!] = PurchaseItem(
          name: name,
          qty: qty,
          price: price,
        );
        editingIndex = null;
      } else {
        items.add(
          PurchaseItem(
            name: name,
            qty: qty,
            price: price,
          ),
        );
      }
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      _itemFocusNode.requestFocus();
    });
    _saveDraft();
  }

  void _saveInvoice() {
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

    final paidAmountValue = double.tryParse(paidAmountController.text) ?? 0.0;
    _performSave(paidAmountValue);
  }

  void _performSave(double paidAmountValue) {
    setState(() => _isSaving = true);

    try {
      final supplier = supplierController.text.trim();

      if (paymentType == 'تحويل' && selectedWallet == null && paidAmountValue > 0) {
        ToastService.show('الرجاء اختيار المحفظة للدفع بالتحويل');
        setState(() => _isSaving = false);
        return;
      }

      // إضافة المشتريات للمخزون
      for (final item in items) {
        InventoryStore.addItem(
          item.name,
          item.qty,
          item.price,
        );
      }

      // تحديث رصيد المورد (المبلغ المتبقي له)
      final dueAmount = total - paidAmountValue;
      SupplierStore.addSupplier(supplier);
      SupplierStore.updateBalance(supplier, dueAmount);

      if (paidAmountValue > 0) {
        final result = FinanceService.withdraw(
          amount: paidAmountValue,
          paymentType: paymentType,
          walletName: selectedWallet,
        );

        if (!result.success) {
          ToastService.show(result.message);
          setState(() => _isSaving = false);
          return;
        }
      }

      final invoiceNumber = DayRecordsStore.getNextInvoiceNumber('purchase').toString();
      const uuid = Uuid();
      final invoiceId = uuid.v4();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'purchase',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'supplier': supplier,
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
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

      setState(() {
        items.clear();
        supplierController.clear();
        paidAmountController.text = '0';
        discountController.text = '0';
        editingIndex = null;
        selectedWallet = null;
        paymentType = 'كاش';
      });
      _supplierFocusNode.requestFocus();
      ToastService.show('تم حفظ الفاتورة وتحديث حساب المورد');
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المشتريات'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                elevation: 2,
              ),
              onPressed: _isSaving ? null : _clearFullInvoice,
              icon: const Icon(Icons.delete_forever, size: 20),
              label: const Text('مسح الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              SearchableDropdownField(
                focusNode: _supplierFocusNode,
                enabled: dayStarted && !_isSaving,
                controller: supplierController,
                label: 'اسم المورد',
                onSearch: (value) => SupplierStore.searchSuppliers(value),
                onSelected: (_) {
                  _itemFocusNode.requestFocus();
                  _saveDraft();
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SearchableDropdownField(
                enabled: dayStarted && !_isSaving,
                controller: itemController,
                focusNode: _itemFocusNode,
                label: 'اسم الصنف',
                onSearch: (value) => InventoryStore.getAllItems()
                    .where((e) => (e['name'] as String)
                        .toLowerCase()
                        .contains(value.toLowerCase()))
                    .map((e) =>
                        "${e['name']} | (المتاح: ${e['quantity']}, آخر شراء: ${e['lastBuyPrice']})")
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
                labelText: 'الكمية',
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocusNode.requestFocus(),
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted && !_isSaving,
                controller: priceController,
                focusNode: _priceFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                labelText: 'سعر الشراء',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (dayStarted && !_isSaving) ? _addItem : null,
                child: Text(editingIndex != null ? 'تعديل البند' : 'إضافة للفاتورة'),
              ),
              const SizedBox(height: 20),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final key = _itemKeys.putIfAbsent(item.name, () => GlobalKey());
                return Card(
                  key: key,
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
                    subtitle: Text('كمية: ${item.qty}  سعر: ${item.price}  إجمالي: ${item.total}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isSaving ? null : () {
                        setState(() => items.removeAt(index));
                        _saveDraft();
                      },
                    ),
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
                onSubmitted: (_) {
                  if (paymentType != 'آجل') _paidAmountFocusNode.requestFocus();
                },
              ),
              const SizedBox(height: 12),
              Text('صافي الفاتورة: ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: paymentType,
                decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                  DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                  DropdownMenuItem(value: 'آجل', child: Text('آجل')),
                ],
                onChanged: (dayStarted && !_isSaving) ? (value) {
                  setState(() {
                    paymentType = value!;
                    if (paymentType != 'آجل') _paidAmountFocusNode.requestFocus();
                  });
                  _saveDraft();
                } : null,
              ),
              if (paymentType == 'تحويل') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWallet,
                  decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                  items: wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (dayStarted && !_isSaving) ? (v) {
                    setState(() => selectedWallet = v);
                    _saveDraft();
                  } : null,
                ),
              ],
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted && !_isSaving,
                  controller: paidAmountController,
                  focusNode: _paidAmountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ المدفوع',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveInvoice(),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (dayStarted && !_isSaving) ? _saveInvoice : null,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الفاتورة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
