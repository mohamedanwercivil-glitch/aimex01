import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/day_records_store.dart';
import '../services/toast_service.dart';

class InventoryAdjustmentsScreen extends StatefulWidget {
  const InventoryAdjustmentsScreen({super.key});

  @override
  State<InventoryAdjustmentsScreen> createState() => _InventoryAdjustmentsScreenState();
}

class _InventoryAdjustmentsScreenState extends State<InventoryAdjustmentsScreen> {
  void _deleteAdjustment(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التعديل؟'),
        content: const Text('سيتم إلغاء التعديل وإرجاع الكمية والسعر كما كانا قبل هذا التعديل. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(id);
              Navigator.pop(context);
              setState(() {});
              ToastService.show('تم إلغاء التعديل واسترجاع البيانات');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adjustments = DayRecordsStore.getAll()
        .where((r) => r['type'] == 'inventory_adjustment')
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('تعديلات المخزن اليوم')),
      body: adjustments.isEmpty
          ? const Center(child: Text('لا توجد تعديلات يدوية اليوم'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: adjustments.length,
              itemBuilder: (context, index) {
                final adj = adjustments[index];
                final time = DateFormat('hh:mm a').format(DateTime.parse(adj['date'] ?? adj['time']));
                final diff = (adj['newQty'] as num) - (adj['oldQty'] as num);
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(adj['itemName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('الكمية: '),
                            Text('${adj['oldQty']} ← ${adj['newQty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text('(${diff >= 0 ? '+' : ''}$diff)', style: TextStyle(color: diff >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('السعر: ${adj['oldPrice']} ← ${adj['newPrice']}'),
                        Text('التوقيت: $time', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _deleteAdjustment(adj['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
