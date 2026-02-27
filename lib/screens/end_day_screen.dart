import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_excel_service.dart';
import '../state/day_state.dart';
import '../services/toast_service.dart';

class EndDayScreen extends StatefulWidget {
  const EndDayScreen({super.key});

  @override
  State<EndDayScreen> createState() => _EndDayScreenState();
}

class _EndDayScreenState extends State<EndDayScreen> {
  bool _isExporting = false;

  void _finishDay() async {
    setState(() => _isExporting = true);

    try {
      // 1. تصدير البيانات (إكسيل + ZIP الفواتير)
      final results = await ExportExcelService.exportDayWithInvoices();
      final excelPath = results['excel'] ?? "";
      final zipPath = results['zip'] ?? "";

      List<XFile> filesToShare = [];
      if (excelPath.isNotEmpty) filesToShare.add(XFile(excelPath));
      if (zipPath.isNotEmpty) filesToShare.add(XFile(zipPath));

      if (filesToShare.isNotEmpty) {
        // 2. مشاركة الملفات
        await Share.shareXFiles(
          filesToShare,
          text: 'تقرير المبيعات وفواتير اليوم - ${DateTime.now().toString().split(' ')[0]}',
        );

        // 3. إنهاء اليوم برمجياً وتصفير البيانات
        DayState.instance.endDay();
        
        // 4. مسح مجلد الفواتير لبدء يوم جديد
        await ExportExcelService.clearDailyInvoices();

        ToastService.show('تم إنهاء اليوم وتصدير التقارير بنجاح');
        Navigator.pop(context);
      } else {
        ToastService.show('فشل في إنشاء التقارير');
      }
    } catch (e) {
      ToastService.show('حدث خطأ أثناء إنهاء اليوم');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنهاء اليوم')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.archive, size: 100, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'عند إنهاء اليوم، سيتم إنشاء تقرير إكسيل مفصل وضغط كافة فواتير المبيعات (PDF) في ملف واحد لمشاركتها.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isExporting ? null : _finishDay,
                child: _isExporting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('إنهاء اليوم ومشاركة التقارير', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
