import 'dart:io';
import 'package:aimex/services/toast_service.dart';
import 'package:aimex/services/logger_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:aimex/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl_lib;
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

  List<SaleItem> items = [];
  int? editingIndex;
  String _originalDataString = "";

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  double currentCustomerBalance = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.editInvoiceId != null) {
      _loadInvoiceForEdit(widget.editInvoiceId!);
    } else {
      _loadDraft();
    }

    customerController.addListener(() {
      _updateCustomerBalance();
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

  void _updateCustomerBalance() {
    final name = customerController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        currentCustomerBalance = CustomerStore.getBalance(name);
      });
    } else {
      setState(() {
        currentCustomerBalance = 0.0;
      });
    }
  }

  void _loadInvoiceForEdit(String invoiceId) {
    final allRecords = DayRecordsStore.getAll();
    final invoiceRecords = allRecords.where((r) => r['invoiceId'] == invoiceId).toList();

    if (invoiceRecords.isNotEmpty) {
      final saleRecords = invoiceRecords.where((r) => r['type'] == 'sale').toList();
      final settlementRecords = invoiceRecords.where((r) => r['type'] == 'settlement').toList();

      if (saleRecords.isNotEmpty) {
        final first = saleRecords.first;
        setState(() {
          customerController.text = first['customer'] ?? '';
          paymentType = (first['paymentType'] == 'نقدي' || first['paymentType'] == 'كاش') ? 'كاش' : first['paymentType'];
          final savedWallet = first['wallet'];
          selectedWallet = (savedWallet == 'نقدي' || savedWallet == '') ? null : savedWallet;
          discountController.text = (first['discount'] ?? 0).toString();
          paidAmountController.text = (first['paidAmount'] ?? 0).toString();
          originalInvoiceNumber = first['invoiceNumber']?.toString();

          items = saleRecords.map((e) => SaleItem(
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
        _updateCustomerBalance();
        _originalDataString = _getCurrentDataString();
      }
    }
  }

  String _getCurrentDataString() {
    return "${customerController.text}-${paymentType}-${selectedWallet}-${discountController.text}-${paidAmountController.text}-${showSecondPayment}-${secondPaidAmountController.text}-${items.map((e) => e.name + e.qty.toString() + e.price.toString()).join()}";
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
        
        showSecondPayment = draft['showSecondPayment'] ?? false;
        secondPaidAmountController.text = draft['secondPaidAmount'] ?? '0';
        secondPaymentType = draft['secondPaymentType'] ?? 'تحويل';
        secondSelectedWallet = draft['secondWallet'];

        final List<dynamic> draftItems = draft['items'] ?? [];
        items = draftItems.map((e) => SaleItem(
          name: e['name'],
          qty: (e['qty'] as num).toDouble(),
          price: (e['price'] as num).toDouble(),
          isReturn: e['isReturn'] ?? false,
        )).toList();
      });
      _updateCustomerBalance();
    } else {
      paidAmountController.text = '0';
      discountController.text = '0';
      secondPaidAmountController.text = '0';
      showSecondPayment = false;
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
      extra: {
        'showSecondPayment': showSecondPayment,
        'secondPaidAmount': secondPaidAmountController.text,
        'secondPaymentType': secondPaymentType,
        'secondWallet': secondSelectedWallet,
      }
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
              LoggerService.userAction('مسح فاتورة مبيعات (Reset)');
              _clearAllFields();
              Navigator.pop(context);
              ToastService.show('تم مسح الفاتورة بنجاح');
            },
            child: const Text('مسح الفاتورة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearAllFields() {
    setState(() {
      items.clear();
      customerController.clear();
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
      currentCustomerBalance = 0.0;
      editingIndex = null;
    });
    DraftStore.clearSalesDraft();
  }

  @override
  void dispose() {
    customerController.dispose();
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    discountController.dispose();
    secondPaidAmountController.dispose();
    _customerFocusNode.dispose();
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

    if (!_isReturnMode) {
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

  Future<void> _saveSale() async {
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

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) {
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
                  child: const Text('ترحيل الباقي لحساب العميل (آجل)'),
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
    final customerName = customerController.text.trim();

    try {
      if (widget.editInvoiceId != null) {
        LoggerService.logicEffect('تعديل فاتورة: عكس الأثر القديم في لحظة الحفظ فقط', {'id': widget.editInvoiceId});
        DayRecordsStore.reverseInvoiceEffects(widget.editInvoiceId!);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (p1 < 0) {
        final check1 = FinanceService.withdraw(amount: p1.abs(), paymentType: paymentType, walletName: paymentType == 'تحويل' ? selectedWallet : null, dryRun: true);
        if (!check1.success) {
          ToastService.show('الدفعة الأولى: ${check1.message}');
          setState(() => _isSaving = false);
          return;
        }
      }
      if (p2 < 0) {
        final check2 = FinanceService.withdraw(amount: p2.abs(), paymentType: secondPaymentType, walletName: secondPaymentType == 'تحويل' ? secondSelectedWallet : null, dryRun: true);
        if (!check2.success) {
          ToastService.show('الدفعة الثانية: ${check2.message}');
          setState(() => _isSaving = false);
          return;
        }
      }

      for (final item in items) {
        if (item.isReturn) {
          InventoryStore.returnItem(item.name, item.qty);
        } else {
          InventoryStore.sellItem(item.name, item.qty);
        }
      }

      double primaryPaid = p1;
      String primaryType = paymentType;
      String? primaryWallet = selectedWallet;
      double secondaryPaid = p2;
      String secondaryType = secondPaymentType;
      String? secondaryWallet = secondSelectedWallet;

      if (showSecondPayment && paymentType != 'كاش' && secondPaymentType == 'كاش') {
        primaryPaid = p2; primaryType = secondPaymentType; primaryWallet = secondSelectedWallet;
        secondaryPaid = p1; secondaryType = paymentType; secondaryWallet = selectedWallet;
      }

      CustomerStore.addCustomer(customerName);
      final invoiceDue = total - primaryPaid;
      CustomerStore.updateBalance(customerName, invoiceDue);
      if (secondaryPaid != 0) {
        CustomerStore.updateBalance(customerName, -secondaryPaid);
      }

      if (primaryPaid != 0) {
        if (primaryPaid > 0) {
          FinanceService.deposit(amount: primaryPaid, paymentType: primaryType, walletName: primaryType == 'تحويل' ? primaryWallet : null);
        } else {
          FinanceService.withdraw(amount: primaryPaid.abs(), paymentType: primaryType, walletName: primaryType == 'تحويل' ? primaryWallet : null);
        }
      }
      if (secondaryPaid != 0) {
        if (secondaryPaid > 0) {
          FinanceService.deposit(amount: secondaryPaid, paymentType: secondaryType, walletName: secondaryType == 'تحويل' ? secondaryWallet : null);
        } else {
          FinanceService.withdraw(amount: secondaryPaid.abs(), paymentType: secondaryType, walletName: secondaryType == 'تحويل' ? secondaryWallet : null);
        }
      }

      final invoiceNumber = originalInvoiceNumber ?? DayRecordsStore.getNextInvoiceNumber('sale').toString();
      const uuid = Uuid();
      final invoiceId = uuid.v4();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'sale',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customer': customerName,
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
          'isReturn': item.isReturn,
          'invoiceTotal': total,
          'paidAmount': primaryPaid,
          'dueAmount': invoiceDue,
          'paymentType': primaryType,
          'wallet': primaryType == 'تحويل' ? primaryWallet ?? '' : 'نقدي',
          'time': DateTime.now().toString(),
          'discount': discount,
        });
      }

      if (secondaryPaid != 0) {
        final dateStr = intl_lib.DateFormat('yyyy-MM-dd').format(DateTime.now());
        DayRecordsStore.addRecord({
          'type': 'settlement',
          'invoiceId': invoiceId,
          'customer': customerName,
          'amount': secondaryPaid,
          'paymentType': secondaryType,
          'wallet': secondaryType == 'تحويل' ? secondaryWallet ?? '' : 'نقدي',
          'date': DateTime.now().toString(),
          'remarks': 'دفعة من فاتورة بيع رقم $invoiceNumber بتاريخ $dateStr',
        });
      }

      // 🔥 حساب الرصيد بدقة للـ PDF
      final finalBalance = CustomerStore.getBalance(customerName);
      final netInvoiceEffect = total - (primaryPaid + secondaryPaid);
      final prevBalForPdf = finalBalance - netInvoiceEffect;

      await _generateAndShareInvoice(
        invoiceNumber, 
        primaryPaid + secondaryPaid, 
        netInvoiceEffect, 
        prevBalForPdf, 
        finalBalance
      );

      _clearAllFields();
      
      if (widget.editInvoiceId != null) {
        Navigator.pop(context);
      } else {
        _customerFocusNode.requestFocus();
      }
      ToastService.show('تم حفظ الفاتورة بنجاح');
    } catch (e, stack) {
      LoggerService.error('خطأ قاتل أثناء حفظ فاتورة المبيعات', error: e, stackTrace: stack);
      ToastService.show('حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAndShareInvoice(
    String invoiceNumber, 
    double totalPaid, 
    double netEffect, 
    double prevBal, 
    double newBal
  ) async {
    try {
      final customerName = customerController.text.trim();
      final pdfData = await PdfService.generateInvoice(
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paidAmount: totalPaid,
        dueAmount: netEffect, // المتبقي من هذه الفاتورة تحديداً
        invoiceId: invoiceNumber,
        previousBalance: prevBal, // المديونية القديمة قبل الفاتورة
        newBalance: newBal, // المديونية الكلية الجديدة
        isPurchase: false,
      );

      final dateStr = intl_lib.DateFormat('d-M-yyyy').format(DateTime.now());
      final fileName = '${customerName}_$dateStr.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة مبيعات - $customerName');
    } catch (e) {
      LoggerService.error('خطأ أثناء توليد أو مشاركة الفاتورة', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayStarted = context.watch<DayState>().dayStarted;
    final p1 = double.tryParse(paidAmountController.text) ?? 0;
    final p2 = showSecondPayment ? (double.tryParse(secondPaidAmountController.text) ?? 0) : 0;
    double futureBalance = currentCustomerBalance + total - (p1 + p2);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editInvoiceId != null ? 'تعديل فاتورة $originalInvoiceNumber' : 'فاتورة بيع جديدة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField(
                      focusNode: _customerFocusNode,
                      enabled: dayStarted && !_isSaving,
                      controller: customerController,
                      label: 'اسم العميل',
                      onSearch: (value) => CustomerStore.searchCustomers(value),
                      onSelected: (v) { LoggerService.userAction('اختيار عميل', {'اسم': v}); _itemFocusNode.requestFocus(); _saveDraft(); },
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
                        color: currentCustomerBalance > 0 ? Colors.red.shade50 : (currentCustomerBalance < 0 ? Colors.green.shade50 : Colors.grey.shade50),
                      ),
                      child: Column(
                        children: [
                          const Text('الرصيد الحالي', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            currentCustomerBalance.abs().toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentCustomerBalance > 0 ? Colors.red : (currentCustomerBalance < 0 ? Colors.green : Colors.black),
                            ),
                          ),
                          Text(
                            currentCustomerBalance > 0 ? 'عليه' : (currentCustomerBalance < 0 ? 'له' : ''),
                            style: TextStyle(fontSize: 10, color: currentCustomerBalance > 0 ? Colors.red : Colors.green),
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
                      onSearch: (value) => InventoryStore.searchAvailableItemNames(value),
                      onSelected: (v) {
                        final p = InventoryStore.getItemBuyPrice(v);
                        priceController.text = p.toString();
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
              _buildPaymentSection(),
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
                      '${futureBalance.abs().toStringAsFixed(2)} ${futureBalance > 0 ? "عليه" : (futureBalance < 0 ? "له" : "")}',
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: dayStarted && !_isSaving ? _saveSale : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.editInvoiceId != null ? 'تعديل وحفظ الفاتورة' : 'حفظ ومشاركة الفاتورة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  if (widget.editInvoiceId == null) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: dayStarted && !_isSaving ? _clearFullInvoice : null,
                      icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 30),
                      tooltip: 'مسح الفاتورة بالكامل',
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 100),
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
            _buildSummaryRow('إجمالي الأصناف:', '${subtotal.toStringAsFixed(2)} ج.م'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الخصم:', style: TextStyle(fontSize: 16)),
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

  Widget _buildPaymentSection() {
    final wallets = CashState.instance.wallets.keys.toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات التحصيل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                items: wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
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
                        items: wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
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
