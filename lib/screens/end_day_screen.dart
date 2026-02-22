import 'package:flutter/material.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import '../services/export_excel_service.dart';

class EndDayScreen extends StatelessWidget {
  const EndDayScreen({super.key});

  Future<void> _endDay(BuildContext context) async {

    if (!DayState.instance.dayStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('اليوم غير مفتوح')),
      );
      return;
    }

    // 🔥 تصدير التقرير
    String path =
    await ExportExcelService.exportDay();

    // 🔥 إنهاء اليوم
    DayState.instance.endDay();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم إنهاء اليوم\nتم إنشاء التقرير في:\n$path',
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cashState = CashState.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنهاء اليوم'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            const Text(
              'ملخص اليوم',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'إجمالي الفلوس: ${cashState.totalMoney}',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 10),

            Text(
              'نقدي: ${cashState.cash}',
            ),

            const SizedBox(height: 10),

            ...cashState.wallets.entries.map(
                  (e) => Padding(
                padding:
                const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${e.key}: ${e.value}',
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () =>
                    _endDay(context),
                child:
                const Text('إنهاء اليوم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
