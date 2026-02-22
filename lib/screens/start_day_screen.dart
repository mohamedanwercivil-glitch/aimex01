import 'package:flutter/material.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';

class StartDayScreen extends StatefulWidget {
  const StartDayScreen({super.key});

  @override
  State<StartDayScreen> createState() =>
      _StartDayScreenState();
}

class _StartDayScreenState
    extends State<StartDayScreen> {

  final cashController = TextEditingController();

  final Map<String, TextEditingController>
  walletControllers = {};

  @override
  void initState() {
    super.initState();

    for (var key in CashState.instance.wallets.keys) {
      walletControllers[key] =
          TextEditingController();
    }
  }

  void _startDay() {
    if (DayState.instance.dayStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('اليوم مفتوح بالفعل')),
      );
      return;
    }

    final cash =
        double.tryParse(cashController.text) ?? 0;

    final Map<String, double> wallets = {};

    walletControllers.forEach((key, controller) {
      wallets[key] =
          double.tryParse(controller.text) ?? 0;
    });

    // 🔹 ضبط النقدي والمحافظ
    CashState.instance.setStartOfDay(
      startCash: cash,
      startWallets: wallets,
    );

    DayState.instance.startDay(cash);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تم بدء اليوم')),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dayStarted =
        DayState.instance.dayStarted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بداية اليوم'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            if (dayStarted)
              Container(
                padding:
                const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: const Text(
                  '⚠ اليوم مفتوح بالفعل - لا يمكن البدء مرة أخرى',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight:
                      FontWeight.bold),
                ),
              ),

            const SizedBox(height: 16),

            // 🔹 خانة النقدي رجعت تاني
            TextField(
              controller: cashController,
              keyboardType:
              TextInputType.number,
              decoration:
              const InputDecoration(
                labelText: 'نقدي',
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 المحافظ
            ...walletControllers.entries
                .map(
                  (entry) => Padding(
                padding:
                const EdgeInsets.only(
                    bottom: 12),
                child: TextField(
                  controller:
                  entry.value,
                  keyboardType:
                  TextInputType
                      .number,
                  decoration:
                  InputDecoration(
                    labelText:
                    entry.key,
                    border:
                    const OutlineInputBorder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                dayStarted
                    ? null
                    : _startDay,
                child:
                const Text('بدء اليوم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
