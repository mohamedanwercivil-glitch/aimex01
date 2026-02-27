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
import '../../data/draft_store.dart';
import '../../services/finance_service.dart';
import '../../state/day_state.dart';
import '../../state/cash_state.dart';

class SaleItem {
  final String name;
  final double qty;
  final double price;

  SaleItem({
    required this.name,
    required this.qty,
    required this.price,
  });

  double get total => qty * price;
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

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
  final Map<String, GlobalKey> _itemKeys = {};

  String paymentType = 'كاش';
  String? selectedWallet;
  bool _isSaving = false;

  List<SaleItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    
    customerController.addListener(_saveDraft);
    paidAmountController.addListener(_saveDraft);
    discountController.addListener(_saveDraft);
  }

  void _loadDraft() {
    final draft = DraftStore.getSalesDraft();
    if (draft != null) {
      setState(() {
        customerController.text = draft['customer'] ?? '';
        paymentType = draft['paymentType'] ?? 'كاش';
        selectedWallet = draft['wallet'];
        discountController.text = draft['discount'] ?? '0';
        paidAmountController.text = draft['paidAmount'] ?? '0';
        final List<dynamic> draftItems = draft['items'] ?? [];
        items = draftItems.map((e) => SaleItem(
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
    DraftStore.saveSalesDraft(
      customer: customerController.text,
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
        content: const Text('سيتم حذف كافة البيانات التي أدخلتها في هذه الفاتورة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
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

    final stockQty = InventoryStore.getItemQty(name);
    if (qty > stockQty && editingIndex == null) {
      ToastService.show('الكمية المتاحة في المخزن لهذا الصنف حالياً هي: $stockQty');
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
    _saveDraft();
  }

  Future<void> _saveSale() async {
    if (_isSaving) return;

    if (!context.read<DayState>().dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) {
      ToastService.show('اكمل بيانات الفاتورة');
      return;
    }

    final paidAmountValue = paymentType == 'آجل'
        ? 0.0
        : double.tryParse(paidAmountController.text) ?? 0.0;
    
    await _performSave(paidAmountValue);
  }

  Future<void> _performSave(double paidAmountValue) async {
    setState(() => _isSaving = true);

    try {
      final customer = customerController.text.trim();
      
      final previousBalance = CustomerStore.getBalance(customer);

      for (final item in items) {
        InventoryStore.sellItem(item.name, item.qty);
      }

      CustomerStore.addCustomer(customer);
      
      final dueAmount = total - paidAmountValue;
      CustomerStore.updateBalance(customer, dueAmount);
      
      final newBalance = CustomerStore.getBalance(customer);

      if (paidAmountValue > 0) {
        FinanceService.deposit(
          amount: paidAmountValue,
          paymentType: paymentType,
          walletName: paymentType == 'تحويل' ? selectedWallet : null,
        );
        context.read<DayState>().addSale(paidAmountValue);
      }

      final invoiceNumber = DayRecordsStore.getNextInvoiceNumber('sale').toString();
      const uuid = Uuid();
      final invoiceId = uuid.v4();
      final now = DateTime.now().toString();

      for (final item in items) {
        DayRecordsStore.addRecord({
          'type': 'sale',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customer': customer,
          'item': item.name,
          'qty': item.qty,
          'price': item.price,
          'total': item.total,
          'invoiceTotal': total,
          'paidAmount': paidAmountValue,
          'dueAmount': dueAmount,
          'paymentType': paymentType,
          'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
          'time': now,
          'discount': discount,
        });
      }

      await _generateAndSharePdf(
        customerName: customer,
        invoiceId: invoiceNumber,
        paidAmount: paidAmountValue,
        dueAmount: dueAmount,
        previousBalance: previousBalance,
        newBalance: newBalance,
      );

      DraftStore.clearSalesDraft();

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
        editingIndex = null;
      });
      _customerFocusNode.requestFocus();
      ToastService.show('تم حفظ الفاتورة وتحديث الرصيد');
    } catch (e) {
      ToastService.show('حدث خطأ أثناء الحفظ');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAndSharePdf({
    required String customerName,
    required String invoiceId,
    required double paidAmount,
    required double dueAmount,
    required double previousBalance,
    required double newBalance,
  }) async {
    final pdfData = await PdfService.generateInvoice(
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: paidAmount,
      dueAmount: dueAmount,
      invoiceId: invoiceId,
      previousBalance: previousBalance,
      newBalance: newBalance,
    );

    // 1. مشاركة الفاتورة الحالية (مجلد مؤقت)
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/invoice_$invoiceId.pdf');
    await tempFile.writeAsBytes(pdfData);

    // 2. حفظ نسخة دائمة لجمعها عند إغلاق اليوم
    final appDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${appDir.path}/daily_invoices');
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }
    final permanentFile = File('${invoicesDir.path}/فاتورة_$invoiceId.pdf');
    await permanentFile.writeAsBytes(pdfData);

    await Share.shareXFiles(
      [XFile(tempFile.path)],
      text: 'فاتورة بيع رقم $invoiceId للعميل: $customerName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة بيع'),
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
                focusNode: _customerFocusNode,
                enabled: dayStarted && !_isSaving,
                controller: customerController,
                label: 'اسم العميل',
                onSearch: (value) => CustomerStore.searchCustomers(value),
                onSelected: (_) {
                  _itemFocusNode.requestFocus();
                  _saveDraft();
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SearchableDropdownField(
                focusNode: _itemFocusNode,
                enabled: dayStarted && !_isSaving,
                controller: itemController,
                label: 'اسم الصنف',
                onSearch: (value) => InventoryStore.searchAvailableItems(value)
                    .map((e) => "${e['name']} | (المتاح: ${e['qty']})")
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
                labelText: 'سعر البيع',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
              ),
              const SizedBox(height: 12),
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
                    subtitle: Text('كمية: ${item.qty} | سعر: ${item.price} | إجمالي: ${item.total}'),
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
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _paidAmountFocusNode.requestFocus(),
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
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted && !_isSaving,
                  controller: paidAmountController,
                  focusNode: _paidAmountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ المدفوع',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveSale(),
                ),
              ],
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (dayStarted && !_isSaving) ? _saveSale : null,
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
