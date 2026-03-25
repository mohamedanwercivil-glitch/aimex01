import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/day_records_store.dart';
import '../data/supplier_store.dart';
import '../models/sale_item.dart';
import '../services/pdf_service.dart';
import '../services/toast_service.dart';
import 'purchase_screen.dart';

class DailyPurchaseInvoicesScreen extends StatefulWidget {
  const DailyPurchaseInvoicesScreen({super.key});

  @override
  State<DailyPurchaseInvoicesScreen> createState() => _DailyPurchaseInvoicesScreenState();
}

class _DailyPurchaseInvoicesScreenState extends State<DailyPurchaseInvoicesScreen> {
  bool _isGeneratingPdf = false;

  void _deleteInvoice(String invoiceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فاتورة الشراء؟'),
        content: const Text('سيتم إلغاء أثر الفاتورة بالكامل من المخزن وحساب المورد والخزنة. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              DayRecordsStore.reverseInvoiceEffects(invoiceId);
              Navigator.pop(context);
              setState(() {});
              ToastService.show('تم حذف الفاتورة وعكس أثرها');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvoicePdf(String invoiceId) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final allRecords = DayRecordsStore.getAll();
      final invoiceRecords = allRecords.where((r) => r['invoiceId'] == invoiceId).toList();
      if (invoiceRecords.isEmpty) return;

      final first = invoiceRecords.first;
      final supplierName = first['supplier'];
      final invoiceNumber = first['invoiceNumber']?.toString() ?? '0';
      
      final List<SaleItem> items = invoiceRecords.map((e) => SaleItem(
        name: e['item'],
        qty: (e['qty'] as num).toDouble(),
        price: (e['price'] as num).toDouble(),
        isReturn: e['isReturn'] ?? false,
      )).toList();

      final pdfData = await PdfService.generateInvoice(
        customerName: supplierName,
        items: items,
        subtotal: (first['invoiceTotal'] as num).toDouble() + (first['discount'] as num? ?? 0).toDouble(),
        discount: (first['discount'] as num? ?? 0).toDouble(),
        total: (first['invoiceTotal'] as num).toDouble(),
        paidAmount: (first['paidAmount'] as num).toDouble(),
        dueAmount: (first['dueAmount'] as num).toDouble(),
        invoiceId: invoiceNumber,
        previousBalance: SupplierStore.getBalance(supplierName) - (first['dueAmount'] as num).toDouble(),
        newBalance: SupplierStore.getBalance(supplierName),
        isPurchase: true,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/فاتورة_شراء_$invoiceNumber.pdf');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة شراء رقم $invoiceNumber');
    } catch (e) {
      ToastService.show('حدث خطأ أثناء توليد الفاتورة');
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = DayRecordsStore.getAll();
    final Map<String, Map<String, dynamic>> invoicesMap = {};
    double totalPurchasesPaid = 0;
    double totalExpenses = 0;
    double totalTransferFees = 0;
    
    for (var record in allRecords) {
      // حساب إجمالي المدفوع في فواتير الشراء
      if (record['type'] == 'purchase' && record['invoiceId'] != null) {
        final id = record['invoiceId'];
        if (!invoicesMap.containsKey(id)) {
          invoicesMap[id] = record;
          totalPurchasesPaid += (record['paidAmount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      
      // حساب إجمالي المصاريف
      if (record['type'] == 'expense') {
        totalExpenses += (record['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // حساب مصاريف التحويل
      if (record['type'] == 'transfer') {
        totalTransferFees += (record['fee'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final invoiceList = invoicesMap.values.toList().reversed.toList();
    final totalOut = totalPurchasesPaid + totalExpenses + totalTransferFees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير الشراء اليومية'),
        bottom: _isGeneratingPdf ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      body: Column(
        children: [
          // كارت إجمالي المبالغ الخارجة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                const Text(
                  'إجمالي المدفوعات والمصاريف اليوم',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totalOut.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('مشتريات', totalPurchasesPaid),
                    _summaryItem('مصاريف', totalExpenses),
                    _summaryItem('رسوم تحويل', totalTransferFees),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: invoiceList.isEmpty
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
                          subtitle: Text('الإجمالي: ${invoice['invoiceTotal']} | مدفوع: ${invoice['paidAmount']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.indigo),
                                onPressed: _isGeneratingPdf ? null : () => _shareInvoicePdf(invoice['invoiceId']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PurchaseScreen(editInvoiceId: invoice['invoiceId']),
                                    ),
                                  ).then((_) => setState(() {}));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteInvoice(invoice['invoiceId']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
