import 'dart:io';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/services/logger_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl_lib;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/inventory_store.dart';
import '../../data/supplier_store.dart';
import '../../data/day_records_store.dart';
import '../../data/draft_store.dart';
import '../../services/finance_service.dart';
import '../../state/day_state.dart';
import '../../state/cash_state.dart';
import '../../models/purchase_item.dart';

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

  final secondPaidAmountController = TextEditingController();
  final _secondPaidAmountFocusNode = FocusNode();
  String secondPaymentType = 'تحويل';
  String? secondSelectedWallet;
  bool showSecondPayment = false;

  final ScrollController _scrollController = ScrollController();

  String paymentType = 'كاش';
  String? selectedWallet;
  bool _isSaving = false;
  String? originalInvoiceNumber;
  bool _isReturnMode = false;

  List<PurchaseItem> items = [];
  int? editingIndex;
  String _originalDataString = "";

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  double currentSupplierBalance = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.editInvoiceId != null) {
      _loadInvoiceForEdit(widget.editInvoiceId!);
    } else {
      _loadDraft();
    }

    supplierController.addListener(() {
      _updateSupplierBalance();
      _saveDraft();
    });
    paidAmountController.addListener(() {
      setState(() {});
      _saveDraft();
    });
    secondPaidAmountController.addListener(() {
      setState(() {});
      _saveDraft();
    });
    discountController.addListener(() {
      setState(() {});
      _saveDraft();
    });
  }

  void _updateSupplierBalance() {
    final name = supplierController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        currentSupplierBalance = SupplierStore.getBalance(name);
      });
    } else {
      setState(() {
        currentSupplierBalance = 0.0;
      });
    }
  }

  void _loadInvoiceForEdit(String invoiceId) {
    final allRecords = DayRecordsStore.getAll();
    final invoiceRecords = allRecords.where((r) => r['invoiceId'] == invoiceId).toList();

    if (invoiceRecords.isNotEmpty) {
      final purchaseRecords = invoiceRecords.where((r) => r['type'] == 'purchase').toList();
      final settlementRecords = invoiceRecords.where((r) => r['type'] == 'supplier_settlement').toList();

      if (purchaseRecords.isNotEmpty) {
        final first = purchaseRecords.first;
        setState(() {
          supplierController.text = first['supplier'] ?? '';
          paymentType = (first['paymentType'] == 'نقدي' || first['paymentType'] == 'كاش') ? 'كاش' : first['paymentType'];
          final savedWallet = first['wallet'];
          selectedWallet = (savedWallet == 'نقدي' || savedWallet == '') ? null : savedWallet;
          discountController.text = (first['discount'] ?? 0).toString();
          paidAmountController.text = (first['paidAmount'] ?? 0).toString();
          originalInvoiceNumber = first['invoiceNumber']?.toString();

          items = purchaseRecords.map((e) => PurchaseItem(
            name: e['item'],
            qty: (e['qty'] as num).toDouble(),
            price: (e['price'] as num).toDouble(),
            isReturn: e['isReturn'] ?? false,
          )).toList();

          if (settlementRecords.isNotEmpty) {
            showSecondPayment = true;
            final second = settlementRecords.first;
            secondPaidAmountController.text = (second['amount'] ?? 0).toString();
            secondPaymentType = second['paymentType'] ?? 'تحويل';
            secondSelectedWallet = second['wallet'] == 'نقدي' ? null : second['wallet'];
          } else {
            showSecondPayment = false;
          }
        });
        _updateSupplierBalance();
        _originalDataString = _getCurrentDataString();
      }
    }
  }

  String _getCurrentDataString() {
    return "${supplierController.text}-${paymentType}-${selectedWallet}-${discountController.text}-${paidAmountController.text}-${showSecondPayment}-${secondPaidAmountController.text}-${items.map((e) => e.name + e.qty.toString() + e.price.toString()).join()}";
  }

  void _loadDraft() {
    final draft = DraftStore.getPurchasesDraft();
    if (draft != null) {
      setState(() {
        supplierController.text = draft['supplier'] ?? ''; 
        paymentType = draft['paymentType'] ?? 'كاش';
        selectedWallet = (draft['wallet'] == 'نقدي') ? null : draft['wallet'];
        discountController.text = draft['discount'] ?? '0';
        paidAmountController.text = draft['paidAmount'] ?? '0';
        
        showSecondPayment = draft['showSecondPayment'] ?? false;
        secondPaidAmountController.text = draft['secondPaidAmount'] ?? '0';
        secondPaymentType = draft['secondPaymentType'] ?? 'تحويل';
        secondSelectedWallet = draft['secondWallet'];

        final List<dynamic> draftItems = draft['items'] ?? [];
        items = draftItems.map((e) => PurchaseItem(
          name: e['name'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
          isReturn: e['isReturn'] ?? false,
        )).toList();
      });
      _updateSupplierBalance();
    } else {
      paidAmountController.text = '0';
      discountController.text = '0';
      secondPaidAmountController.text = '0';
      showSecondPayment = false;
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
      extra: {
        'showSecondPayment': showSecondPayment,
        'secondPaidAmount': secondPaidAmountController.text,
        'secondPaymentType': secondPaymentType,
        'secondWallet': secondSelectedWallet,
      }
    );
  }

  void _deleteFullInvoicePermanently() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفاتورة نهائياً'),
        content: const Text('سيتم حذف الفاتورة وعكس كل آثارها من المخزن والحسابات. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              LoggerService.userAction('حذف فاتورة شراء نهائياً', {'رقم': widget.editInvoiceId});
              DayRecordsStore.reverseInvoiceEffects(widget.editInvoiceId!);
              Navigator.pop(context);
              Navigator.pop(context);
              ToastService.show('تم حذف الفاتورة بنجاح');
            },
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.red)),
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
        content: const Text('هل تريد مسح فاتورة الشراء الحالية والبدء من جديد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              LoggerService.userAction('مسح بيانات الفاتورة الحالية (Reset)');
              setState(() {
                items.clear();
                supplierController.clear();
                itemController.clear();
                qtyController.clear();
                priceController.clear();
                paidAmountController.text = '0';
                discountController.text = '0';
                secondPaidAmountController.text = '0';
                showSecondPayment = false;
                paymentType = 'كاش';
                selectedWallet = null;
                originalInvoiceNumber = null;
                _isReturnMode = false;
                currentSupplierBalance = 0.0;
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
    supplierController.dispose();
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    discountController.dispose();
    secondPaidAmountController.dispose();
    _supplierFocusNode.dispose();
    _itemFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    _discountFocusNode.dispose();
    _paidAmountFocusNode.dispose();
    _secondPaidAmountFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = itemController.text.trim();
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;

    LoggerService.userAction('إضافة صنف للفاتورة', {'صنف': name, 'كمية': qty, 'سعر': price, 'مرتجع': _isReturnMode});

    if (name.isEmpty || qty <= 0 || price <= 0) {
      ToastService.show('اكمل بيانات الصنف');
      return;
    }

    if (_isReturnMode) {
      final stockQty = InventoryStore.getItemQty(name);
      if (qty > stockQty) {
        ToastService.show('الكمية المتاحة في المخزن حالياً هي: $stockQty');
        return;
      }
    }

    final existingIndex = items.indexWhere((item) => item.name == name && item.isReturn == _isReturnMode);
    if (existingIndex != -1 && existingIndex != editingIndex) {
      ToastService.show('هذا الصنف موجود بالفعل في القائمة بالأسفل');
      if (_scrollController.hasClients) {
        final targetOffset = existingIndex * 65.0;
        _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
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

    if (widget.editInvoiceId != null && _originalDataString == _getCurrentDataString()) {
      ToastService.show('لم يتم إجراء أي تعديلات على الفاتورة');
      Navigator.pop(context);
      return;
    }

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
      ToastService.show('يجب اختيار المحفظة لطريقة الدفع الأولى');
      return;
    }
    if (showSecondPayment && secondPaymentType == 'تحويل' && secondSelectedWallet == null) {
      ToastService.show('يجب اختيار المحفظة لطريقة الدفع الثانية');
      return;
    }

    final p1 = paymentType == 'آجل' ? 0.0 : (double.tryParse(paidAmountController.text) ?? 0.0);
    final p2 = showSecondPayment ? (double.tryParse(secondPaidAmountController.text) ?? 0.0) : 0.0;
    final totalPaid = p1 + p2;

    if (paymentType != 'آجل' && totalPaid < total) {
      final diff = total - totalPaid;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تنبيه: المبلغ المدفوع أقل من الإجمالي'),
          content: Text('صافي الفاتورة: ${total.toStringAsFixed(2)}\nالمبلغ المدفوع: ${totalPaid.toStringAsFixed(2)}\nالعجز: ${diff.toStringAsFixed(2)}\n\nكيف تريد معالجة العجز؟'),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () { Navigator.pop(context); _performSave(p1, p2); },
                  child: const Text('ترحيل الباقي لحساب المورد (آجل)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final currentDiscount = double.tryParse(discountController.text) ?? 0.0;
                    discountController.text = (currentDiscount + diff).toStringAsFixed(2);
                    setState(() {});
                    _performSave(p1, p2);
                  },
                  child: const Text('اعتبار العجز خصم إضافي'),
                ),
                TextButton(
                  onPressed: () { Navigator.pop(context); _paidAmountFocusNode.requestFocus(); },
                  child: const Text('تعديل المبلغ المدفوع'),
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }

    _performSave(p1, p2);
  }

  void _performSave(double p1, double p2) async {
    setState(() => _isSaving = true);
    final supplierName = supplierController.text.trim();

    try {
      if (widget.editInvoiceId != null) {
        LoggerService.logicEffect('تعديل فاتورة: عكس الأثر القديم في لحظة الحفظ فقط', {'id': widget.editInvoiceId});
        DayRecordsStore.reverseInvoiceEffects(widget.editInvoiceId!);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (p1 > 0) {
        final check1 = FinanceService.withdraw(amount: p1, paymentType: paymentType, walletName: paymentType == 'تحويل' ? selectedWallet : null, dryRun: true);
        if (!check1.success) {
          ToastService.show('الدفعة الأولى: ${check1.message}');
          setState(() => _isSaving = false);
          return;
        }
      }
      if (p2 > 0) {
        final check2 = FinanceService.withdraw(amount: p2, paymentType: secondPaymentType, walletName: secondPaymentType == 'تحويل' ? secondSelectedWallet : null, dryRun: true);
        if (!check2.success) {
          ToastService.show('الدفعة الثانية: ${check2.message}');
          setState(() => _isSaving = false);
          return;
        }
      }

      if (p1 > 0) {
        FinanceService.withdraw(amount: p1, paymentType: paymentType, walletName: paymentType == 'تحويل' ? selectedWallet : null);
      }
      if (p2 > 0) {
        FinanceService.withdraw(amount: p2, paymentType: secondPaymentType, walletName: secondPaymentType == 'تحويل' ? secondSelectedWallet : null);
      }

      for (final item in items) {
        if (item.isReturn) {
          InventoryStore.sellItem(item.name, item.qty);
        } else {
          InventoryStore.addItem(item.name, item.qty, item.price);
        }
      }

      SupplierStore.addSupplier(supplierName);
      final invoiceDue = total - p1;
      SupplierStore.updateBalance(supplierName, invoiceDue);
      if (p2 != 0) {
        SupplierStore.updateBalance(supplierName, -p2);
      }

      final invoiceNumber = originalInvoiceNumber ?? DayRecordsStore.getNextInvoiceNumber('purchase').toString();
      const uuid = Uuid();
      final invoiceId = uuid.v4();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'purchase',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'supplier': supplierName,
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
          'isReturn': item.isReturn,
          'invoiceTotal': total,
          'paymentType': paymentType,
          'wallet': (paymentType == 'تحويل' && selectedWallet != null) ? selectedWallet : 'نقدي',
          'paidAmount': p1,
          'dueAmount': invoiceDue,
          'time': DateTime.now().toString(),
          'discount': discount,
        });
      }

      if (p2 != 0) {
        final dateStr = intl_lib.DateFormat('yyyy-MM-dd').format(DateTime.now());
        DayRecordsStore.addRecord({
          'type': 'supplier_settlement',
          'invoiceId': invoiceId,
          'supplier': supplierName,
          'amount': p2,
          'wallet': (secondPaymentType == 'تحويل' && secondSelectedWallet != null) ? secondSelectedWallet : 'نقدي',
          'date': DateTime.now().toString(),
          'remarks': 'دفعة من فاتورة شراء رقم $invoiceNumber بتاريخ $dateStr',
        });
      }

      context.read<DayState>().addPurchase(subtotal, discount: discount);

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
          secondPaidAmountController.text = '0';
          discountController.text = '0';
          editingIndex = null;
          selectedWallet = null;
          paymentType = 'كاش';
          showSecondPayment = false;
          _isReturnMode = false;
          currentSupplierBalance = 0.0;
        });
        _supplierFocusNode.requestFocus();
      }
      ToastService.show('تم حفظ الفاتورة بنجاح');
    } catch (e, stack) {
      LoggerService.error('خطأ قاتل أثناء حفظ فاتورة المشتريات', error: e, stackTrace: stack);
      ToastService.show('حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    final p1 = double.tryParse(paidAmountController.text) ?? 0;
    final p2 = showSecondPayment ? (double.tryParse(secondPaidAmountController.text) ?? 0) : 0;
    double futureBalance = currentSupplierBalance + total - (p1 + p2);

    String? currentSelectedWallet = selectedWallet;
    if (currentSelectedWallet != null && !wallets.contains(currentSelectedWallet)) {
      currentSelectedWallet = null;
    }
    String? currentSecondSelectedWallet = secondSelectedWallet;
    if (currentSecondSelectedWallet != null && !wallets.contains(currentSecondSelectedWallet)) {
      currentSecondSelectedWallet = null;
    }

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField(
                      focusNode: _supplierFocusNode,
                      enabled: dayStarted && !_isSaving,
                      controller: supplierController,
                      label: 'اسم المورد',
                      onSearch: (value) => SupplierStore.searchSuppliers(value),
                      onSelected: (v) { LoggerService.userAction('اختيار مورد', {'اسم': v}); _itemFocusNode.requestFocus(); _saveDraft(); },
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: currentSupplierBalance > 0 ? Colors.red.shade50 : (currentSupplierBalance < 0 ? Colors.green.shade50 : Colors.grey.shade50),
                      ),
                      child: Column(
                        children: [
                          const Text('الرصيد الحالي', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            currentSupplierBalance.abs().toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentSupplierBalance > 0 ? Colors.red : (currentSupplierBalance < 0 ? Colors.green : Colors.black),
                            ),
                          ),
                          Text(
                            currentSupplierBalance > 0 ? 'علينا له' : (currentSupplierBalance < 0 ? 'لنا عنده' : ''),
                            style: TextStyle(fontSize: 10, color: currentSupplierBalance > 0 ? Colors.red : Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField(
                      focusNode: _itemFocusNode,
                      enabled: dayStarted && !_isSaving,
                      controller: itemController,
                      label: 'اسم الصنف',
                      onSearch: (value) => InventoryStore.searchItemNames(value),
                      onSelected: (v) {
                        // فصل اسم الصنف عن باقي النص (المتاح والسعر)
                        final itemName = v.split(' | ').first;
                        // جلب آخر سعر شراء لهذا الصنف تلقائياً
                        final p = InventoryStore.getItemBuyPrice(itemName);
                        setState(() {
                          priceController.text = p.toString();
                        });
                        _qtyFocusNode.requestFocus();
                      },
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableTextField(
                      focusNode: _qtyFocusNode,
                      enabled: dayStarted && !_isSaving,
                      controller: qtyController,
                      labelText: 'الكمية',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _priceFocusNode.requestFocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SelectableTextField(
                      focusNode: _priceFocusNode,
                      enabled: dayStarted && !_isSaving,
                      controller: priceController,
                      labelText: 'السعر',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _isReturnMode ? Colors.red : Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: _isReturnMode ? Colors.red.withOpacity(0.1) : null,
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('مرتجع', style: TextStyle(fontSize: 12)),
                        ),
                        Switch(
                          value: _isReturnMode,
                          onChanged: (v) => setState(() => _isReturnMode = v),
                          activeThumbColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: dayStarted && !_isSaving ? _addItem : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    child: Text(editingIndex == null ? 'إضافة' : 'تعديل'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: items.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد أصناف في الفاتورة')))
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _scrollController,
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              dense: true,
                              title: Text(item.name, style: TextStyle(color: item.isReturn ? Colors.red : null, fontWeight: item.isReturn ? FontWeight.bold : null)),
                              subtitle: Text('كمية: ${item.qty} × سعر: ${item.price}${item.isReturn ? " (مرتجع)" : ""}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${item.total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        editingIndex = index;
                                        itemController.text = item.name;
                                        qtyController.text = item.qty.toString();
                                        priceController.text = item.price.toString();
                                        _isReturnMode = item.isReturn;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => setState(() {
                                      items.removeAt(index);
                                      _saveDraft();
                                    }),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              _buildPaymentSection(wallets),
              const Divider(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد بعد الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${futureBalance.abs().toStringAsFixed(2)} ${futureBalance > 0 ? "علينا" : (futureBalance < 0 ? "لنا" : "")}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: futureBalance > 0 ? Colors.red : (futureBalance < 0 ? Colors.green : Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: dayStarted && !_isSaving ? _saveInvoice : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.editInvoiceId != null ? 'تعديل وحفظ الفاتورة' : 'حفظ فاتورة الشراء', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('إجمالي المشتريات:', '${subtotal.toStringAsFixed(2)} ج.م'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الخصم المكتسب:', style: TextStyle(fontSize: 16)),
                SizedBox(
                  width: 100,
                  child: SelectableTextField(
                    focusNode: _discountFocusNode,
                    controller: discountController,
                    labelText: 'الخصم',
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _paidAmountFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSummaryRow('الصافي النهائي:', '${total.toStringAsFixed(2)} ج.م', isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(List<String> wallets) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات الدفع للمورد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: paymentType,
              decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                DropdownMenuItem(value: 'آجل', child: Text('آجل (على الحساب)')),
              ],
              onChanged: _isSaving ? null : (v) => setState(() => paymentType = v!),
            ),
            if (paymentType == 'تحويل') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedWallet,
                decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                items: wallets.map((w) => {
                  "الاسم": w,
                  "الرصيد": CashState.instance.wallets[w]
                }).map((w) => DropdownMenuItem(value: w['الاسم'] as String, child: Text("${w['الاسم']} (${(w['الرصيد'] as num).toStringAsFixed(0)})"))).toList(),
                onChanged: _isSaving ? null : (v) => setState(() => selectedWallet = v),
              ),
            ],
            if (paymentType != 'آجل') ...[
              const SizedBox(height: 12),
              SelectableTextField(
                focusNode: _paidAmountFocusNode,
                enabled: !_isSaving,
                controller: paidAmountController,
                labelText: 'المبلغ المدفوع حالياً',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 15),
            if (!showSecondPayment)
              Center(
                child: TextButton.icon(
                  onPressed: _isSaving ? null : () => setState(() => showSecondPayment = true),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                  label: const Text('إضافة طريقة دفع أخرى', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ),
            if (showSecondPayment) ...[
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('طريقة دفع ثانية (متعدد)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _isSaving ? null : () => setState(() {
                      showSecondPayment = false;
                      secondPaidAmountController.text = '0';
                      _saveDraft();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: secondPaymentType,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع الثانية', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                        DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                      ],
                      onChanged: _isSaving ? null : (v) => setState(() { secondPaymentType = v!; _saveDraft(); }),
                    ),
                    if (secondPaymentType == 'تحويل') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: secondSelectedWallet,
                        decoration: const InputDecoration(labelText: 'اختر المحفظة الثانية', border: OutlineInputBorder()),
                        items: wallets.map((w) => {
                          "الاسم": w,
                          "الرصيد": CashState.instance.wallets[w]
                        }).map((w) => DropdownMenuItem(value: w['الاسم'] as String, child: Text("${w['الاسم']} (${(w['الرصيد'] as num).toStringAsFixed(0)})"))).toList(),
                        onChanged: _isSaving ? null : (v) => setState(() { secondSelectedWallet = v; _saveDraft(); }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SelectableTextField(
                      focusNode: _secondPaidAmountFocusNode,
                      enabled: !_isSaving,
                      controller: secondPaidAmountController,
                      labelText: 'المبلغ المدفوع (الثاني)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? 18 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: isTotal ? 18 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Colors.blue.shade900 : null)),
      ],
    );
  }
}
