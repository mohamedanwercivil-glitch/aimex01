import 'package:flutter/material.dart';
import '../../data/day_records_store.dart';
import 'new_sale_screen.dart';

class DailyInvoicesScreen extends StatelessWidget {
  const DailyInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // جلب كل السجلات وتصفية فواتير البيع فقط
    final allRecords = DayRecordsStore.getAll();
    
    // تجميع السجلات حسب invoiceId لعرض كل فاتورة كبند واحد
    final Map<String, Map<String, dynamic>> invoices = {};
    
    for (var record in allRecords) {
      if (record['type'] == 'sale' && record['invoiceId'] != null) {
        final id = record['invoiceId'];
        if (!invoices.containsKey(id)) {
          invoices[id] = record;
        }
      }
    }

    final invoiceList = invoices.values.toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('فواتير البيع اليومية')),
      body: invoiceList.isEmpty
          ? const Center(child: Text('لا توجد فواتير بيع اليوم'))
          : ListView.builder(
              itemCount: invoiceList.length,
              itemBuilder: (context, index) {
                final invoice = invoiceList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        invoice['invoiceNumber'].toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('العميل: ${invoice['customer']}'),
                    subtitle: Text('الإجمالي: ${invoice['invoiceTotal']} | ${invoice['paymentType']}'),
                    trailing: const Icon(Icons.edit, color: Colors.blue),
                    onTap: () {
                      // عند الضغط، نفتح شاشة البيع ونمرر لها بيانات الفاتورة للتعديل
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewSaleScreen(editInvoiceId: invoice['invoiceId']),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
