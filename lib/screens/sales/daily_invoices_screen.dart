import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/day_records_store.dart';
import '../../data/customer_store.dart';
import '../../models/sale_item.dart';
import '../../services/pdf_service.dart';
import '../../services/toast_service.dart';
import '../../services/logger_service.dart';
import 'new_sale_screen.dart';

class DailyInvoicesScreen extends StatefulWidget {
  const DailyInvoicesScreen({super.key});

  @override
  State<DailyInvoicesScreen> createState() => _DailyInvoicesScreenState();
}

class _DailyInvoicesScreenState extends State<DailyInvoicesScreen> {
  bool _isGeneratingPdf = false;

  void _deleteInvoice(String invoiceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فاتورة البيع؟'),
        content: const Text('سيتم إلغاء أثر الفاتورة بالكامل من المخزن وحساب العميل والخزنة. هل أنت متأكد؟'),
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
      
      // تصفية السجلات لاستخراج سجلات المبيعات فقط (الأصناف)
      final saleRecords = invoiceRecords.where((r) => r['type'] == 'sale').toList();
      
      if (saleRecords.isEmpty) {
        ToastService.show('لم يتم العثور على بيانات المبيعات لهذه الفاتورة');
        return;
      }

      final first = saleRecords.first;
      final customerName = first['customer'] ?? 'عميل غير معروف';
      final invoiceNumber = first['invoiceNumber']?.toString() ?? '0';
      
      // تحويل السجلات إلى كائنات SaleItem مع التأكد من عدم وجود قيم فارغة
      final List<SaleItem> items = saleRecords.map((e) => SaleItem(
        name: e['item'] ?? 'صنف غير معروف',
        qty: (e['qty'] as num? ?? 0).toDouble(),
        price: (e['price'] as num? ?? 0).toDouble(),
        isReturn: e['isReturn'] ?? false,
      )).toList();

      final discount = (first['discount'] as num? ?? 0).toDouble();
      final invoiceTotal = (first['invoiceTotal'] as num? ?? 0).toDouble();
      final paidAmount = (first['paidAmount'] as num? ?? 0).toDouble();
      final dueAmount = (first['dueAmount'] as num? ?? 0).toDouble();
      final expenses = (first['additionalExpenses'] as num? ?? 0).toDouble();

      // حساب المجموع الفرعي قبل الخصم والمصاريف
      final calculatedSubtotal = items.fold(0.0, (sum, item) => sum + item.total);

      // جلب سجلات السداد المرتبطة بهذه الفاتورة (إن وجدت)
      final settlementRecords = invoiceRecords.where((r) => r['type'] == 'settlement').toList();
      final totalSecondaryPaid = settlementRecords.fold(0.0, (sum, e) => sum + (e['amount'] as num? ?? 0).toDouble());
      
      final totalCollected = paidAmount + totalSecondaryPaid;
      
      // حساب الرصيد
      final currentBal = CustomerStore.getBalance(customerName);
      // الأثر الصافي لهذه الفاتورة على حساب العميل
      final netInvoiceEffect = invoiceTotal - totalCollected;

      final pdfData = await PdfService.generateInvoice(
        customerName: customerName,
        items: items,
        subtotal: calculatedSubtotal,
        discount: discount,
        total: invoiceTotal,
        paidAmount: totalCollected,
        dueAmount: netInvoiceEffect,
        invoiceId: invoiceNumber,
        previousBalance: currentBal - netInvoiceEffect,
        newBalance: currentBal,
      );

      final dateStr = DateFormat('d-M-yyyy').format(DateTime.tryParse(first['time'] ?? '') ?? DateTime.now());
      final fileName = '${customerName}_$dateStr.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles([XFile(file.path)], text: 'فاتورة بيع - $customerName');
    } catch (e, stack) {
      LoggerService.error('خطأ أثناء توليد PDF من شاشة الفواتير', error: e, stackTrace: stack);
      ToastService.show('حدث خطأ فني أثناء توليد الفاتورة');
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = DayRecordsStore.getAll();
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
      appBar: AppBar(
        title: const Text('فواتير البيع اليومية'),
        bottom: _isGeneratingPdf ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
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
                        invoice['invoiceNumber']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('العميل: ${invoice['customer']}'),
                    subtitle: Text('الإجمالي: ${invoice['invoiceTotal']} | ${invoice['paymentType']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.teal),
                          onPressed: _isGeneratingPdf ? null : () => _shareInvoicePdf(invoice['invoiceId']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewSaleScreen(editInvoiceId: invoice['invoiceId']),
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
    );
  }
}
