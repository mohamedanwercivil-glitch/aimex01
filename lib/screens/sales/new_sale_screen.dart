import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/inventory_store.dart';
import '../../data/customer_store.dart';
import '../../data/day_records_store.dart';
import '../../services/finance_service.dart';
import '../../state/day_state.dart';
import '../../state/cash_state.dart';

class SaleItem {
  final String name;
  final int qty;
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
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final paidAmountController = TextEditingController();

  String? selectedItem;
  String paymentType = 'كاش';
  String? selectedWallet;

  final List<SaleItem> items = [];
  int? editingIndex;

  double get total => items.fold(0.0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    paidAmountController.text = '0';
  }

  @override
  void dispose() {
    customerController.dispose();
    qtyController.dispose();
    priceController.dispose();
    paidAmountController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = selectedItem;
    final qty = int.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    if (name == null || name.isEmpty || qty <= 0 || price <= 0) return;
    
    final availableQty = InventoryStore.getItemQty(name);
    if (qty > availableQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الكمية غير كافية للصنف $name. الكمية المتاحة: $availableQty')),
      );
      return;
    }


    setState(() {
      if (editingIndex != null) {
        items[editingIndex!] = SaleItem(name: name, qty: qty, price: price);
        editingIndex = null;
      } else {
        items.add(SaleItem(name: name, qty: qty, price: price));
      }
      selectedItem = null;
      qtyController.clear();
      priceController.clear();
    });
  }

  void _saveSale() {
    if (!context.read<DayState>().dayStarted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب بدء اليوم أولاً')),
      );
      return;
    }

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) return;

    final paidAmount = paymentType == 'آجل' ? 0.0 : double.tryParse(paidAmountController.text) ?? 0.0;
    if (paidAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ المدفوع لا يمكن أن يكون سالباً')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الكمية غير كافية للصنف ${item.name}')),
        );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
        return;
      }
      context.read<DayState>().addSale(paidAmount);
    }

    final dueAmount = total - paidAmount;

    // 🔥 تسجيل كل بند في سجل اليوم
    for (final item in items) {
      DayRecordsStore.addRecord({
        'type': 'sale',
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
        'date': DateTime.now().toString(),
      });
    }

    setState(() {
      items.clear();
      customerController.clear();
      selectedItem = null;
      qtyController.clear();
      priceController.clear();
      paidAmountController.text = '0';
      paymentType = 'كاش';
      selectedWallet = null;
      editingIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الفاتورة')),
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
              Autocomplete<String>(
                optionsBuilder: (text) =>
                    CustomerStore.searchCustomers(text.text),
                onSelected: (value) => customerController.text = value,
                fieldViewBuilder: (context, controller, focusNode, _) {
                  controller.text = customerController.text;
                  return TextField(
                    enabled: dayStarted,
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'اسم العميل',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => customerController.text = value,
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: InventoryStore.box.listenable(),
                builder: (context, box, child) {
                  final availableItems = InventoryStore.searchAvailableItems('');
                  return DropdownButtonFormField<String>(
                    value: selectedItem,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصنف',
                      border: OutlineInputBorder(),
                    ),
                    items: availableItems.map<DropdownMenuItem<String>>((item) {
                      return DropdownMenuItem<String>(
                        value: item['name'] as String,
                        child: Text(item['name'] as String),
                      );
                    }).toList(),
                    onChanged: dayStarted
                        ? (value) {
                            setState(() {
                              selectedItem = value;
                            });
                          }
                        : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: dayStarted,
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: dayStarted,
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر البيع',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
                    onTap: dayStarted ? () {
                      setState(() {
                        editingIndex = index;
                        selectedItem = item.name;
                        qtyController.text = item.qty.toString();
                        priceController.text = item.price.toString();
                      });
                    } : null,
                    title: Text(item.name),
                    subtitle: Text(
                        'كمية: ${item.qty} | سعر: ${item.price} | إجمالي: ${item.total}'),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Text(
                'إجمالي الفاتورة: $total',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
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
                onChanged: dayStarted ? (value) {
                  setState(() {
                    paymentType = value!;
                  });
                } : null,
              ),
              if (paymentType != 'آجل') ...[
                const SizedBox(height: 12),
                TextField(
                  enabled: dayStarted,
                  controller: paidAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    border: OutlineInputBorder(),
                  ),
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
                  onChanged: dayStarted ? (value) => setState(() => selectedWallet = value) : null,
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
