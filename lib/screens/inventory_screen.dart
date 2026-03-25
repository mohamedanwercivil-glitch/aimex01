import 'package:flutter/material.dart';
import '../data/inventory_store.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool _hideZeroStock = false; // التحكم في إخفاء الرصيد الصفر

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = searchController.text.toLowerCase();
    final allItems = InventoryStore.getAllItems();

    setState(() {
      items = allItems.where((item) {
        final matchesSearch = item['name'].toString().toLowerCase().contains(query);
        final hasStock = ((item['quantity'] as num?)?.toDouble() ?? 0) != 0;

        if (_hideZeroStock) {
          return matchesSearch && hasStock;
        }
        return matchesSearch;
      }).toList();
    });
  }

  double _calculateTotalInventoryValue() {
    double total = 0;
    // نحسب القيمة بناءً على كل الأصناف في المخزن (ليس فقط المفلترة)
    for (var item in InventoryStore.getAllItems()) {
      double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      double price = (item['avgBuyPrice'] as num?)?.toDouble() ?? 0.0;
      if (qty > 0) {
        total += (qty * price);
      }
    }
    return total;
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final name = item['name'];
    final qtyController = TextEditingController(text: item['quantity'].toString());
    final priceController = TextEditingController(text: item['lastBuyPrice'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل صنف: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الكمية الموجودة فعلياً'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'آخر سعر شراء'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(qtyController.text) ?? 0.0;
              final newPrice = double.tryParse(priceController.text) ?? 0.0;
              
              InventoryStore.updateItem(name, newQty, newPrice);
              Navigator.pop(context);
              _refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث بيانات الصنف بنجاح')),
              );
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _calculateTotalInventoryValue();

    return Scaffold(
      appBar: AppBar(title: const Text('جرد المخزن')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 💰 كارت إجمالي قيمة المخزن
            Card(
              color: Colors.blue.shade900,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي قيمة المخزن:',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${totalValue.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(color: Colors.yellowAccent, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 🔍 مربع البحث والفلتر
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: const InputDecoration(
                      labelText: 'بحث عن صنف...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    const Text('إخفاء الصفر', style: TextStyle(fontSize: 10)),
                    Switch(
                      value: _hideZeroStock,
                      onChanged: (val) {
                        setState(() {
                          _hideZeroStock = val;
                          _applyFilters();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('لا توجد أصناف مطابقة للبحث'),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final quantity = item['quantity'] ?? 0.0;
                        final lastBuyPrice = (item['lastBuyPrice'] as num?)?.toDouble() ?? 0.0;
                        final avgPrice = (item['avgBuyPrice'] as num?)?.toDouble() ?? lastBuyPrice;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () => _showEditDialog(item),
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: quantity == 0 ? Colors.red.shade100 : Colors.blue.shade100,
                              child: Icon(
                                Icons.inventory_2, 
                                color: quantity == 0 ? Colors.red : Colors.blue
                              ),
                            ),
                            title: Text(
                              item['name'] ?? 'بدون اسم',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الكمية المتاحة: $quantity', 
                                    style: TextStyle(
                                      color: quantity == 0 ? Colors.red : Colors.green, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('المتوسط: ${avgPrice.toStringAsFixed(2)}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600)),
                                      Text('آخر شراء: ${lastBuyPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
