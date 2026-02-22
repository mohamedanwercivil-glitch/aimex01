import 'package:flutter/material.dart';
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
  final itemController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final paidController = TextEditingController();

  String paymentStatus = 'دفع';
  String paymentType = 'كاش';
  String? selectedWallet;

  final List<SaleItem> items = [];
  int? editingIndex;

  double get total =>
      items.fold(0.0, (sum, item) => sum + item.total);

  void _addItem() {
    final name = itemController.text.trim();
    final qty = int.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    if (name.isEmpty || qty <= 0 || price <= 0) return;

    setState(() {
      if (editingIndex != null) {
        items[editingIndex!] = SaleItem(
          name: name,
          qty: qty,
          price: price,
        );
        editingIndex = null;
      } else {
        items.add(
          SaleItem(name: name, qty: qty, price: price),
        );
      }

      itemController.clear();
      qtyController.clear();
      priceController.clear();
    });
  }

  void _saveSale() {
    if (!DayState.instance.dayStarted) return;

    final customer = customerController.text.trim();
    if (customer.isEmpty || items.isEmpty) return;

    for (final item in items) {
      final success =
      InventoryStore.sellItem(item.name, item.qty);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'الكمية غير كافية للصنف ${item.name}')),
        );
        return;
      }
    }

    CustomerStore.addCustomer(customer);

    double paidAmount = 0;

    if (paymentStatus == 'دفع') {
      paidAmount =
          double.tryParse(paidController.text) ?? 0;

      if (paidAmount <= 0 || paidAmount > total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('المبلغ غير صحيح')),
        );
        return;
      }

      final result = FinanceService.deposit(
        amount: paidAmount,
        paymentType: paymentType,
        walletName:
        paymentType == 'تحويل' ? selectedWallet : null,
      );

      if (!result.success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
            SnackBar(content: Text(result.message)));
        return;
      }

      DayState.instance.addSale(paidAmount);
    }

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
        'paymentStatus': paymentStatus,
        'paidAmount': paidAmount,
        'paymentType':
        paymentStatus == 'دفع' ? paymentType : 'أجل',
        'wallet': paymentType == 'تحويل'
            ? selectedWallet ?? ''
            : 'نقدي',
        'date': DateTime.now().toString(),
      });
    }

    setState(() {
      items.clear();
      customerController.clear();
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      paidController.clear();
      paymentStatus = 'دفع';
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
    final wallets =
    CashState.instance.wallets.keys.toList();

    return Scaffold(
      appBar:
      AppBar(title: const Text('فاتورة بيع')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [

              Autocomplete<String>(
                optionsBuilder: (text) =>
                    CustomerStore.searchCustomers(
                        text.text),
                onSelected: (value) =>
                customerController.text = value,
                fieldViewBuilder:
                    (context, controller,
                    focusNode, _) {
                  controller.text =
                      customerController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration:
                    const InputDecoration(
                      labelText: 'اسم العميل',
                      border:
                      OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                    customerController
                        .text = value,
                  );
                },
              ),

              const SizedBox(height: 12),

              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (text) =>
                    InventoryStore
                        .searchAvailableItems(
                        text.text),
                displayStringForOption:
                    (option) => option['name'],
                onSelected: (option) =>
                itemController.text =
                option['name'],
                fieldViewBuilder:
                    (context, controller,
                    focusNode, _) {
                  controller.text =
                      itemController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration:
                    const InputDecoration(
                      labelText: 'اسم الصنف',
                      border:
                      OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                    itemController.text =
                        value,
                  );
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: qtyController,
                keyboardType:
                TextInputType.number,
                decoration:
                const InputDecoration(
                  labelText: 'الكمية',
                  border:
                  OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: priceController,
                keyboardType:
                TextInputType.number,
                decoration:
                const InputDecoration(
                  labelText: 'سعر البيع',
                  border:
                  OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _addItem,
                child: Text(editingIndex != null
                    ? 'تعديل البند'
                    : 'إضافة للفاتورة'),
              ),

              const SizedBox(height: 20),

              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return Card(
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        editingIndex = index;
                        itemController.text =
                            item.name;
                        qtyController.text =
                            item.qty.toString();
                        priceController.text =
                            item.price
                                .toString();
                      });
                    },
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
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: paymentStatus,
                decoration:
                const InputDecoration(
                  labelText: 'حالة الدفع',
                  border:
                  OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'دفع',
                      child: Text('دفع')),
                  DropdownMenuItem(
                      value: 'أجل',
                      child: Text('أجل')),
                ],
                onChanged: (value) =>
                    setState(() =>
                    paymentStatus =
                    value!),
              ),

              if (paymentStatus == 'دفع') ...[
                const SizedBox(height: 12),

                TextField(
                  controller: paidController,
                  keyboardType:
                  TextInputType.number,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'المبلغ المدفوع',
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: paymentType,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'طريقة الدفع',
                    border:
                    OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'كاش',
                        child: Text('كاش')),
                    DropdownMenuItem(
                        value: 'تحويل',
                        child: Text('تحويل')),
                  ],
                  onChanged: (value) =>
                      setState(() =>
                      paymentType =
                      value!),
                ),

                if (paymentType == 'تحويل') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedWallet,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'اختر المحفظة',
                      border:
                      OutlineInputBorder(),
                    ),
                    items: wallets
                        .map((wallet) =>
                        DropdownMenuItem(
                          value: wallet,
                          child:
                          Text(wallet),
                        ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() =>
                        selectedWallet =
                            value),
                  ),
                ]
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveSale,
                child:
                const Text('حفظ الفاتورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
