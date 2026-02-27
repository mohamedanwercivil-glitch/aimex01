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
    required String invoiceId, // يمثل الآن الرقم المتسلسل (مثلاً "1")
  }) async {
    final pdf = pw.Document();

    // تحميل الخط العربي
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
                pw.Divider(height: 30),
                _buildItemsTable(items, ttf),
                pw.Divider(),
                _buildTotals(subtotal, discount, total, paidAmount, dueAmount, ttf),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    '*** المبلغ المتبقي خاص بهذه الفاتورة فقط وليس إجمالي الرصيد ***',
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600, font: ttf, fontSize: 10),
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
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(height: 10),
          pw.Text('الإجمالي: ${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
          pw.SizedBox(height: 5),
          pw.Text('الخصم: ${discount.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
          pw.SizedBox(height: 5),
          pw.Text('صافي الفاتورة: ${total.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, font: font)),
          pw.SizedBox(height: 10),
          pw.Text('المبلغ المدفوع: ${paidAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
          pw.SizedBox(height: 5),
          pw.Text('المتبقي من الفاتورة: ${dueAmount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red, font: font)),
        ],
      ),
    );
  }
}
