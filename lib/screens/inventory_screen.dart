import 'package:flutter/material.dart';
import '../data/inventory_store.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState
    extends State<InventoryScreen> {

  final searchController = TextEditingController();

  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    items = InventoryStore.getAllItems();
  }

  void _search(String query) {
    final allItems =
    InventoryStore.getAllItems();

    setState(() {
      items = allItems
          .where((item) => item['name']
          .toLowerCase()
          .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: const Text('المخزن')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // 🔍 مربع البحث
            TextField(
              controller: searchController,
              onChanged: _search,
              decoration:
              const InputDecoration(
                labelText: 'بحث عن صنف',
                prefixIcon: Icon(Icons.search),
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: items.isEmpty
                  ? const Center(
                child: Text(
                    'لا يوجد نتائج'),
              )
                  : ListView.builder(
                itemCount:
                items.length,
                itemBuilder:
                    (context, index) {
                  final item =
                  items[index];

                  return Card(
                    child: ListTile(
                      title:
                      Text(item['name']),
                      subtitle: Text(
                        'الكمية: ${item['quantity']}\n'
                            'متوسط سعر الشراء: ${item['avgPrice'].toStringAsFixed(2)}\n'
                            'آخر سعر شراء: ${item['lastBuyPrice'].toStringAsFixed(2)}',
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
