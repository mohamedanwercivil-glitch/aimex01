import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../screens/sales/new_sale_screen.dart'; 

class PdfService {
  static Future<Uint8List> generateInvoice({
    required String customerName,
    required List<SaleItem> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
    required double dueAmount,
    required String invoiceId,
    required double previousBalance,
    required double newBalance,
  }) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Tajawal-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('فاتورة بيع', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: ttf)),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('العميل: $customerName', style: pw.TextStyle(fontSize: 16, font: ttf)),
                    pw.Text('رقم الفاتورة: $invoiceId', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text('التاريخ: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: pw.TextStyle(font: ttf)),
                pw.Divider(height: 20),
                
                _buildItemsTable(items, ttf),
                
                pw.SizedBox(height: 20),
                
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // كشف الحساب المصغر
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.TableBorder.all(),
                          color: PdfColors.grey100,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ملخص الحساب:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            pw.SizedBox(height: 5),
                            _buildBalanceRow('الرصيد السابق:', previousBalance, ttf),
                            _buildBalanceRow('إجمالي الفاتورة:', total, ttf),
                            _buildBalanceRow('المبلغ المدفوع:', paidAmount, ttf),
                            pw.Divider(),
                            _buildBalanceRow('الرصيد الحالي:', newBalance, ttf, isTotal: true),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 40),
                    // تفاصيل الفاتورة الحالية
                    pw.Expanded(
                      flex: 1,
                      child: _buildTotals(subtotal, discount, total, paidAmount, dueAmount, ttf),
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    'شكرًا لتعاملكم معنا',
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700, font: ttf, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildBalanceRow(String label, double amount, pw.Font font, {bool isTotal = false}) {
    String status = amount > 0 ? '(عليه)' : (amount < 0 ? '(له)' : '');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: isTotal ? 11 : 10, fontWeight: isTotal ? pw.FontWeight.bold : null)),
          pw.Text('${amount.abs().toStringAsFixed(2)} $status', 
            style: pw.TextStyle(font: font, fontSize: isTotal ? 11 : 10, fontWeight: isTotal ? pw.FontWeight.bold : null, 
            color: amount > 0 ? PdfColors.red : PdfColors.green)),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<SaleItem> items, pw.Font font) {
    const tableHeaders = ['الصنف', 'الكمية', 'السعر', 'الإجمالي'];

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: items.map((item) {
        return [
          item.name,
          item.qty.toStringAsFixed(2),
          item.price.toStringAsFixed(2),
          item.total.toStringAsFixed(2),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, font: font),
      cellAlignment: pw.Alignment.center,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      cellStyle: pw.TextStyle(fontSize: 10, font: font),
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _buildTotals(
    double subtotal,
    double discount,
    double total,
    double paidAmount,
    double dueAmount,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('الإجمالي: ${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
        pw.Text('الخصم: ${discount.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
        pw.Divider(),
        pw.Text('صافي الفاتورة: ${total.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, font: font)),
        pw.Text('المبلغ المدفوع: ${paidAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
        pw.SizedBox(height: 5),
        pw.Text('المتبقي من الفاتورة: ${dueAmount.toStringAsFixed(2)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red, font: font)),
      ],
    );
  }
}
