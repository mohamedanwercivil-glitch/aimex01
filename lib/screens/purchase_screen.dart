// ignore_for_file: deprecated_member_use

import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/inventory_store.dart';
import '../data/supplier_store.dart';
import '../data/day_records_store.dart';
import '../services/finance_service.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../widgets/searchable_dropdown_field.dart';

class PurchaseItem {
  final String name;
  final String unit;
  final double qty;
  final double price;

  PurchaseItem({
    required this.name,
    required this.unit,
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
  final discountController = TextEditingController(); // Added discount controller

  String selectedUnit = 'صغرى';
  String paymentType = 'كاش';
  String? selectedWallet;

  final List<PurchaseItem> items = [];
  int? editingIndex;

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get discount => double.tryParse(discountController.text) ?? 0.0;
  double get total => subtotal - discount;

  @override
  void initState() {
    super.initState();
    paidAmountController.text = '0';
    discountController.text = '0'; // Initialize discount
  }

  @override
  void dispose() {
    supplierController.dispose();
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    discountController.dispose(); // Dispose discount controller
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
        items[editingIndex!] = PurchaseItem(
          name: name,
          unit: selectedUnit,
          qty: qty,
          price: price,
        );
        editingIndex = null;
      } else {
        items.add(
          PurchaseItem(
            name: name,
            unit: selectedUnit,
            qty: qty,
            price: price,
          ),
        );
      }
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      selectedUnit = 'صغرى';
    });
  }

  void _saveInvoice() {
    if (!context.read<DayState>().dayStarted) {
      ToastService.show('يجب بدء اليوم أولاً');
      return;
    }

    final supplier = supplierController.text.trim();
    if (supplier.isEmpty || items.isEmpty) {
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

    if (paymentType == 'آجل') {
      _performSave(0);
      return;
    }

    final paidAmount = double.tryParse(paidAmountController.text) ?? 0.0;
    if (paidAmount < 0) {
      ToastService.show('المبلغ المدفوع لا يمكن أن يكون سالباً');
      return;
    }

    final dueAmount = total - paidAmount;

    if (dueAmount > 0) {
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
    final supplier = supplierController.text.trim();
    final dueAmount = total - paidAmount;

    if (paymentType == 'تحويل' && selectedWallet == null && paidAmount > 0) {
      ToastService.show('الرجاء اختيار المحفظة للدفع بالتحويل');
      return;
    }

    SupplierStore.addSupplier(supplier);

    for (final item in items) {
      InventoryStore.addItem(
        item.name,
        item.qty,
        item.price,
      );
    }

    if (paidAmount > 0) {
      final result = FinanceService.withdraw(
        amount: paidAmount,
        paymentType: paymentType,
        walletName: selectedWallet,
      );

      if (!result.success) {
        ToastService.show(result.message);
        return;
      }
    }

    const uuid = Uuid();
    final invoiceId = uuid.v4();

    for (final item in items) {
      DayRecordsStore.addRecord({
        'type': 'purchase',
        'invoiceId': invoiceId,
        'supplier': supplier,
        'item': item.name,
        'qty': item.qty,
        'price': item.price,
        'total': item.total,
        'invoiceTotal': total,
        'paymentType': paymentType,
        'wallet': paymentType == 'تحويل' ? selectedWallet ?? '' : 'نقدي',
        'paidAmount': paidAmount,
        'dueAmount': dueAmount,
        'time': DateTime.now().toString(),
        'discount': discount, // Added discount
      });
    }

    setState(() {
      items.clear();
      supplierController.clear();
      paidAmountController.text = '0';
      discountController.text = '0'; // Clear discount
      editingIndex = null;
      selectedWallet = null;
      paymentType = 'كاش';
      selectedUnit = 'صغرى';
    });

    ToastService.show('تم حفظ الفاتورة');
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();
    final dayStarted = context.watch<DayState>().dayStarted;

    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SearchableDropdownField(
                enabled: dayStarted,
                controller: supplierController,
                label: 'اسم المورد',
                onSearch: (value) => SupplierStore.searchSuppliers(value),
              ),
              const SizedBox(height: 12),
              SearchableDropdownField(
                enabled: dayStarted,
                controller: itemController,
                label: 'اسم الصنف',
                onSearch: (value) => InventoryStore.getAllItems()
                    .map((e) => e['name'] as String)
                    .where((name) =>
                        name.toLowerCase().contains(value.toLowerCase()))
                    .toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'الوحدة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'صغرى', child: Text('صغرى')),
                  DropdownMenuItem(value: 'كبرى', child: Text('كبرى')),
                ],
                onChanged: dayStarted
                    ? (value) => setState(() => selectedUnit = value!)
                    : null,
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                labelText: 'الكمية',
              ),
              const SizedBox(height: 12),
              SelectableTextField(
                enabled: dayStarted,
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                labelText: 'سعر الوحدة',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: dayStarted ? _addItem : null,
                child: Text(editingIndex != null ? 'تعديل البند' : 'إضافة للفاتورة'),
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
                              selectedUnit = item.unit;
                            });
                          }
                        : null,
                    title: Text('${item.name} (${item.unit})'),
                    subtitle: Text(
                        'كمية: ${item.qty}  سعر: ${item.price}  إجمالي: ${item.total}'),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Text(
                'الإجمالي: ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
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
                        });
                      }
                    : null,
              ),
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
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                SelectableTextField(
                  enabled: dayStarted,
                  controller: paidAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  labelText: 'المبلغ المدفوع',
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: dayStarted ? _saveInvoice : null,
                child: const Text('حفظ الفاتورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
