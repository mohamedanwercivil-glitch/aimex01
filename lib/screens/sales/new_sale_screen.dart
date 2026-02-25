import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
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

class _DisplayableSaleItem {
  final String name;
  final double qty;

  _DisplayableSaleItem({required this.name, required this.qty});
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final customerController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final paidAmountController = TextEditingController();
  final discountController = TextEditingController();

  String? selectedItemName;
  String paymentType = 'كاش';
  String? selectedWallet;

  final List<SaleItem> items = [];
  int? editingIndex;
  Key _customerAutocompleteKey = UniqueKey();
  Key _itemAutocompleteKey = UniqueKey();

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
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    discountController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = selectedItemName;
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;

    if (name == null || name.isEmpty || qty <= 0 || price <= 0) {
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
      selectedItemName = null;
      _itemAutocompleteKey = UniqueKey(); // Reset Autocomplete
      qtyController.clear();
      priceController.clear();
    });
  }

  void _saveSale() {
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
      _showConfirmationDialog(dueAmount, () => _performSave(paidAmount));
    } else {
      _performSave(paidAmount);
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

  void _performSave(double paidAmount) {
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
    final invoiceId = uuid.v4();
    final now = DateTime.now().toString();

    for (final item in items) {
      DayRecordsStore.addRecord({
        'type': 'sale',
        'invoiceId': invoiceId,
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

    setState(() {
      items.clear();
      customerController.clear();
      _customerAutocompleteKey = UniqueKey();
      selectedItemName = null;
      _itemAutocompleteKey = UniqueKey();
      qtyController.clear();
      priceController.clear();
      paidAmountController.text = '0';
      discountController.text = '0';
      paymentType = 'كاش';
      selectedWallet = null;
      editingIndex = null;
    });

    ToastService.show('تم حفظ الفاتورة');
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
              Autocomplete<String>(
                key: _customerAutocompleteKey,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return CustomerStore.searchCustomers(textEditingValue.text);
                },
                onSelected: (value) {
                  customerController.text = value;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return SelectableTextField(
                    enabled: dayStarted,
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) => customerController.text = value,
                    labelText: 'اسم العميل',
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: InventoryStore.box.listenable(),
                builder: (context, box, child) {
                  return Autocomplete<_DisplayableSaleItem>(
                    key: _itemAutocompleteKey,
                    displayStringForOption: (option) => option.name,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<_DisplayableSaleItem>.empty();
                      }
                      return InventoryStore.searchAvailableItems(textEditingValue.text)
                          .map((item) => _DisplayableSaleItem(name: item['name'] as String, qty: item['qty'] as double));
                    },
                    onSelected: (_DisplayableSaleItem selection) {
                      setState(() {
                        selectedItemName = selection.name;
                      });
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 32,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              shrinkWrap: true,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return InkWell(
                                  onTap: () {
                                    onSelected(option);
                                  },
                                  child: ListTile(
                                    title: Text(option.name),
                                    trailing: Text('المتاح: ${option.qty}'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController fieldController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted) {
                      return SelectableTextField(
                        controller: fieldController,
                        focusNode: fieldFocusNode,
                        labelText: 'اسم الصنف',
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                labelText: 'الكمية',
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                labelText: 'سعر البيع',
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
                              selectedItemName = item.name;
                              qtyController.text = item.qty.toString();
                              priceController.text = item.price.toString();
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                labelText: 'الخصم',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'صافي الفاتورة: ${total.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
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
                        });
                      }
                    : null,
                value: paymentType,
              ),
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted,
                  controller: paidAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ المدفوع',
                ),
              ],
              if (paymentType == 'تحويل') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
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
                  value: selectedWallet,
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
