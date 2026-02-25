import 'package:aimex/services/toast_service.dart';
import 'package:flutter/material.dart';
import '../services/background_service.dart';
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
      ToastService.show('اليوم مفتوح بالفعل');
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
    BackgroundService.scheduleEndOfDayTask();

    ToastService.show('تم بدء اليوم');

    Navigator.pop(context);
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
        child: SingleChildScrollView(
          child: Column(
            children: [

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
      ),
    );
  }
}
