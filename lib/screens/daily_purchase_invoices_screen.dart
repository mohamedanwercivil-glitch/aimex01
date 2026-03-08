import 'package:flutter/material.dart';
import '../data/day_records_store.dart';
import 'purchase_screen.dart';

class DailyPurchaseInvoicesScreen extends StatelessWidget {
  const DailyPurchaseInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final allRecords = DayRecordsStore.getAll();
    
    final Map<String, Map<String, dynamic>> invoices = {};
    
    for (var record in allRecords) {
      if (record['type'] == 'purchase' && record['invoiceId'] != null) {
        final id = record['invoiceId'];
        if (!invoices.containsKey(id)) {
          invoices[id] = record;
        }
      }
    }

    final invoiceList = invoices.values.toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('فواتير الشراء اليومية')),
      body: invoiceList.isEmpty
          ? const Center(child: Text('لا توجد فواتير شراء اليوم'))
          : ListView.builder(
              itemCount: invoiceList.length,
              itemBuilder: (context, index) {
                final invoice = invoiceList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        invoice['invoiceNumber']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('المورد: ${invoice['supplier']}'),
                    subtitle: Text('الإجمالي: ${invoice['invoiceTotal']} | ${invoice['paymentType']}'),
                    trailing: const Icon(Icons.edit, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PurchaseScreen(editInvoiceId: invoice['invoiceId']),
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
