import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/sale_item.dart'; 

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
    bool isPurchase = false,
  }) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Tajawal-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    
    pw.MemoryImage? logo;
    pw.MemoryImage? vodafoneLogo;
    pw.MemoryImage? instapayLogo;
    pw.MemoryImage? whatsappLogo;

    try {
      final logoData = await rootBundle.load("assets/icon/AIMEX.png");
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    try {
      final vData = await rootBundle.load("assets/icon/vodafone_logo.png");
      vodafoneLogo = pw.MemoryImage(vData.buffer.asUint8List());
    } catch (_) {}

    try {
      final iData = await rootBundle.load("assets/icon/instapay_logo.png");
      instapayLogo = pw.MemoryImage(iData.buffer.asUint8List());
    } catch (_) {}

    try {
      final wData = await rootBundle.load("assets/icon/whatsapp_logo.png");
      whatsappLogo = pw.MemoryImage(wData.buffer.asUint8List());
    } catch (_) {}

    final title = isPurchase ? 'فاتورة شراء' : (invoiceId.startsWith('R-') ? 'مرتجع مبيعات' : 'فاتورة بيع');
    final partyLabel = isPurchase ? 'المورد' : 'العميل';

    pdf.addPage(
      pw.MultiPage( 
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttf,
        ),
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logo != null) 
                        pw.Container(
                          width: 50,
                          height: 50,
                          margin: const pw.EdgeInsets.only(left: 10),
                          child: pw.Image(logo),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('عمر انور', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: ttf, color: PdfColors.blue900)),
                          pw.Text('للتجارة والتوريدات العامة', style: pw.TextStyle(fontSize: 10, font: ttf, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          // أرقام التواصل (واتساب) في الهيدر
                          pw.Row(
                            children: [
                              _buildLogoContactRow(whatsappLogo, '01062350317', ttf, PdfColors.blue700, size: 12),
                              pw.SizedBox(width: 10),
                              _buildLogoContactRow(whatsappLogo, '0150854570', ttf, PdfColors.blue700, size: 12),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: ttf)),
                      pw.Text('الرقم: $invoiceId', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                      pw.Text('التاريخ: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 5),
              
              pw.Row(
                children: [
                  pw.Text('$partyLabel: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: ttf)),
                  pw.Text(customerName, style: pw.TextStyle(fontSize: 14, font: ttf)),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('شركة الريان', style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: pw.TextStyle(font: ttf, fontSize: 9)),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          _buildItemsTable(items, ttf),
          
          pw.SizedBox(height: 20),
          
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (!isPurchase)
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                    color: PdfColors.grey50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ملخص الحساب الشخصي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, font: ttf, color: PdfColors.blue900)),
                      pw.SizedBox(height: 8),
                      _buildBalanceRow('الرصيد السابق:', previousBalance, ttf),
                      _buildBalanceRow(invoiceId.startsWith('R-') ? 'إجمالي المرتجع:' : 'إجمالي الفاتورة:', total, ttf),
                      _buildBalanceRow(invoiceId.startsWith('R-') ? 'المبلغ المردود:' : 'المبلغ المدفوع:', paidAmount, ttf),
                      pw.Divider(color: PdfColors.grey300),
                      _buildBalanceRow('الرصيد الحالي:', newBalance, ttf, isTotal: true),
                    ],
                  ),
                ),
              ),
              if (!isPurchase) pw.SizedBox(width: 40),
              pw.Expanded(
                flex: 1,
                child: _buildTotals(subtotal, discount, total, paidAmount, dueAmount, ttf, invoiceId.startsWith('R-') || isPurchase),
              ),
            ],
          ),
          
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('شكرًا لتعاملكم معنا', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('عمر انور - للتجارة والتوريدات العامة', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),

          pw.SizedBox(height: 30),
          // قسم أرقام المحافظ في آخر الفاتورة
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            child: pw.Column(
              children: [
                pw.Text('طرق الدفع المتاحة:', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    _buildLogoContactRow(instapayLogo, '01507276172', ttf, PdfColors.purple800, size: 11),
                    pw.SizedBox(width: 40),
                    _buildLogoContactRow(vodafoneLogo, '01016754232', ttf, PdfColors.red800, size: 11),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildLogoContactRow(pw.MemoryImage? image, String value, pw.Font font, PdfColor color, {double size = 10}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (image != null) 
          pw.Container(
            width: size + 8,
            height: size + 8,
            margin: const pw.EdgeInsets.only(left: 5),
            child: pw.Image(image),
          ),
        pw.Text(value, style: pw.TextStyle(fontSize: size, font: font, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildBalanceRow(String label, double amount, pw.Font font, {bool isTotal = false}) {
    String status = amount > 0 ? '(عليه)' : (amount < 0 ? '(له)' : '');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: isTotal ? 10 : 9)),
          pw.Text('${amount.abs().toStringAsFixed(2)} $status', 
            style: pw.TextStyle(font: font, fontSize: isTotal ? 10 : 9, fontWeight: isTotal ? pw.FontWeight.bold : null,
            color: amount > 0 ? PdfColors.red : PdfColors.green)),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<SaleItem> items, pw.Font font) {
    const tableHeaders = ['الصنف', 'الكمية', 'السعر', 'الإجمالي'];

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: items.map((item) {
        return [
          item.name,
          item.qty.toStringAsFixed(2),
          item.price.toStringAsFixed(2),
          item.total.toStringAsFixed(2),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, font: font, color: PdfColors.white),
      cellAlignment: pw.Alignment.center,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blue900,
      ),
      cellStyle: pw.TextStyle(fontSize: 10, font: font),
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
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
    bool isReturnOrPurchase,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('الإجمالي:', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text(subtotal.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
        if (!isReturnOrPurchase)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('الخصم:', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text(discount.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('الصافي:', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(total.toStringAsFixed(2), style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue900)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('المدفوع:', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text(paidAmount.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
        if (!isReturnOrPurchase)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('المتبقي من الفاتورة:', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red)),
            pw.Text(dueAmount.toStringAsFixed(2), style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red)),
          ],
        ),
      ],
    );
  }
}
