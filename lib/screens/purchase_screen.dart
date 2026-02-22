import 'package:flutter/material.dart';
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
  final int qty;
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

  String selectedUnit = 'صغرى';
  String paymentType = 'كاش';
  String? selectedWallet;

  final List<PurchaseItem> items = [];
  int? editingIndex;

  double get total =>
      items.fold(0, (sum, item) => sum + item.total);

  void _addItem() {
    final name = itemController.text.trim();
    final qty = int.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    if (name.isEmpty || qty <= 0 || price <= 0) return;

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
    if (!DayState.instance.dayStarted) return;

    final supplier = supplierController.text.trim();
    if (supplier.isEmpty || items.isEmpty) return;

    SupplierStore.addSupplier(supplier);

    for (final item in items) {
      InventoryStore.addItem(
        item.name,
        item.qty,
        item.price,
      );
    }

    final result = FinanceService.withdraw(
      amount: total,
      paymentType: paymentType,
      walletName: selectedWallet,
    );

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    // 🔥 تسجيل كل بند في سجل اليوم
    for (final item in items) {
      DayRecordsStore.addRecord({
        'type': 'purchase',
        'supplier': supplier,
        'item': item.name,
        'qty': item.qty,
        'price': item.price,
        'total': item.total,
        'invoiceTotal': total,
        'paymentType': paymentType,
        'wallet': paymentType == 'تحويل'
            ? selectedWallet ?? ''
            : 'نقدي',
        'date': DateTime.now().toString(),
      });
    }

    setState(() {
      items.clear();
      supplierController.clear();
      editingIndex = null;
      selectedWallet = null;
      paymentType = 'كاش';
      selectedUnit = 'صغرى';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الفاتورة')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = CashState.instance.wallets.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [

              SearchableDropdownField(
                controller: supplierController,
                label: 'اسم المورد',
                onSearch: (value) =>
                    SupplierStore.searchSuppliers(value),
              ),

              const SizedBox(height: 12),

              SearchableDropdownField(
                controller: itemController,
                label: 'اسم الصنف',
                onSearch: (value) =>
                    InventoryStore.getAllItems()
                        .map((e) => e['name'] as String)
                        .where((name) => name
                        .toLowerCase()
                        .contains(value.toLowerCase()))
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
                  DropdownMenuItem(
                      value: 'صغرى', child: Text('صغرى')),
                  DropdownMenuItem(
                      value: 'كبرى', child: Text('كبرى')),
                ],
                onChanged: (value) =>
                    setState(() => selectedUnit = value!),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر الوحدة',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: paymentType,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'كاش', child: Text('كاش')),
                  DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
                ],
                onChanged: (value) =>
                    setState(() => paymentType = value!),
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
                  onChanged: (value) =>
                      setState(() => selectedWallet = value),
                ),
              ],

              const SizedBox(height: 16),

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
                        itemController.text = item.name;
                        qtyController.text =
                            item.qty.toString();
                        priceController.text =
                            item.price.toString();
                        selectedUnit = item.unit;
                      });
                    },
                    title:
                    Text('${item.name} (${item.unit})'),
                    subtitle: Text(
                        'كمية: ${item.qty}  سعر: ${item.price}  إجمالي: ${item.total}'),
                  ),
                );
              }),

              const SizedBox(height: 20),

              Text(
                'إجمالي الفاتورة: $total',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveInvoice,
                child: const Text('حفظ الفاتورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
