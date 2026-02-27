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

  String paymentType = 'كاش';
  String? selectedWallet;

  final List<SaleItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  @override
  void initState() {
    super.initState();
    paidAmountController.text = '0';
    discountController.text = '0';
  }

  @override
  void dispose() {
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

    final availableQty = InventoryStore.getItemQty(name);
    if (qty > availableQty) {
      ToastService.show(
          'الكمية غير كافية للصنف $name. الكمية المتاحة: $availableQty');
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

  Future<void> _saveSale() async {
    if (!context.read<DayState>().dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) {
      ToastService.show('اكمل بيانات الفاتورة');
      return;
    }

    if (discount < 0) {
      ToastService.show('الخصم لا يمكن أن يكون سالباً');
      return;
    }
    if (total < 0) {
      ToastService.show('الإجمالي بعد الخصم لا يمكن أن يكون سالباً');
      return;
    }

    final paidAmount = paymentType == 'آجل'
        ? 0.0
        : double.tryParse(paidAmountController.text) ?? 0.0;
    if (paidAmount < 0) {
      ToastService.show('المبلغ المدفوع لا يمكن أن يكون سالباً');
      return;
    }

    final dueAmount = total - paidAmount;

    if (dueAmount > 0 && paymentType != 'آجل') {
      _showConfirmationDialog(dueAmount, () async => await _performSave(paidAmount));
    } else {
      await _performSave(paidAmount);
    }
  }

  void _showConfirmationDialog(double dueAmount, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الفاتورة'),
        content: Text(
            'المبلغ المدفوع أقل من الإجمالي. سيتم اعتبار الفاتورة آجل بمبلغ متبقي قدره ${dueAmount.toStringAsFixed(2)}. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSave(double paidAmount) async {
    final customer = customerController.text.trim();

    for (final item in items) {
      final success = InventoryStore.sellItem(item.name, item.qty);
      if (!success) {
        ToastService.show('الكمية غير كافية للصنف ${item.name}');
        return;
      }
    }

    CustomerStore.addCustomer(customer);

    if (paidAmount > 0) {
      final result = FinanceService.deposit(
        amount: paidAmount,
        paymentType: paymentType,
        walletName: paymentType == 'تحويل' ? selectedWallet : null,
      );
      if (!result.success) {
        ToastService.show(result.message);
        return;
      }
      context.read<DayState>().addSale(paidAmount);
    }

    final dueAmount = total - paidAmount;
    const uuid = Uuid();
    final invoiceId = uuid.v4(); // المعرف الداخلي
    final invoiceNumber = DayRecordsStore.getNextInvoiceNumber('sale').toString(); // الرقم التسلسلي للـ PDF والإكسيل
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
        'paidAmount': paidAmount,
        'dueAmount': dueAmount,
        'paymentType': paymentType,
        'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
        'time': now,
        'discount': discount,
      });
    }

    // Generate and share PDF using the serial invoice number
    await _generateAndSharePdf(
      customerName: customer,
      invoiceId: invoiceNumber, // نمرر هنا الرقم التسلسلي (مثلاً "1")
      paidAmount: paidAmount,
      dueAmount: dueAmount,
    );

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

    ToastService.show('تم حفظ الفاتورة');
  }

  Future<void> _generateAndSharePdf({
    required String customerName,
    required String invoiceId,
    required double paidAmount,
    required double dueAmount,
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
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/invoice_$invoiceId.pdf');
    await file.writeAsBytes(pdfData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'فاتورة بيع رقم $invoiceId للعميل: $customerName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة بيع')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SearchableDropdownField(
                focusNode: _customerFocusNode,
                enabled: dayStarted,
                controller: customerController,
                label: 'اسم العميل',
                onSearch: (value) => CustomerStore.searchCustomers(value),
                onSelected: (_) => _itemFocusNode.requestFocus(),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SearchableDropdownField(
                focusNode: _itemFocusNode,
                enabled: dayStarted,
                controller: itemController,
                label: 'اسم الصنف',
                onSearch: (value) => InventoryStore.searchAvailableItems(value)
                    .map((e) => "${e['name']} (المتاح: ${e['qty']})")
                    .toList(),
                onSelected: (value) {
                  // Extract only the item name from the selected string
                  final name = value.split(' (المتاح:')[0];
                  itemController.text = name;
                  _qtyFocusNode.requestFocus();
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: qtyController,
                focusNode: _qtyFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                labelText: 'الكمية',
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocusNode.requestFocus(),
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: priceController,
                focusNode: _priceFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                labelText: 'سعر البيع',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: dayStarted ? _addItem : null,
                child: Text(
                    editingIndex != null ? 'تعديل البند' : 'إضافة للفاتورة'),
              ),
              const SizedBox(height: 20),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  child: ListTile(
                    onTap: dayStarted
                        ? () {
                            setState(() {
                              editingIndex = index;
                              itemController.text = item.name;
                              qtyController.text = item.qty.toString();
                              priceController.text = item.price.toString();
                              _itemFocusNode.requestFocus();
                            });
                          }
                        : null,
                    title: Text(item.name),
                    subtitle: Text(
                        'كمية: ${item.qty} | سعر: ${item.price} | إجمالي: ${item.total}'),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Text(
                'الإجمالي: ${subtotal.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: discountController,
                focusNode: _discountFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                labelText: 'الخصم',
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _paidAmountFocusNode.requestFocus(),
              ),
              const SizedBox(height: 12),
              Text(
                'صافي الفاتورة: ${total.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: paymentType,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                  DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                  DropdownMenuItem(value: 'آجل', child: Text('آجل')),
                ],
                onChanged: dayStarted
                    ? (value) {
                        setState(() {
                          paymentType = value!;
                          if (paymentType != 'آجل') {
                            _paidAmountFocusNode.requestFocus();
                          }
                        });
                      }
                    : null,
              ),
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted,
                  controller: paidAmountController,
                  focusNode: _paidAmountFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ المدفوع',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveSale(),
                ),
              ],
              if (paymentType == 'تحويل') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWallet,
                  decoration: const InputDecoration(
                    labelText: 'اختر المحفظة',
                    border: OutlineInputBorder(),
                  ),
                  items: wallets
                      .map((wallet) => DropdownMenuItem(
                            value: wallet,
                            child: Text(wallet),
                          ))
                      .toList(),
                  onChanged: dayStarted
                      ? (value) => setState(() => selectedWallet = value)
                      : null,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: dayStarted ? _saveSale : null,
                child: const Text('حفظ الفاتورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
