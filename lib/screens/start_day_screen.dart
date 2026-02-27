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
  final Map<String, TextEditingController> walletControllers = {};
  
  // إضافة FocusNodes للتنقل بين الحقول
  final FocusNode _cashFocusNode = FocusNode();
  final Map<String, FocusNode> _walletFocusNodes = {};

  @override
  void initState() {
    super.initState();

    final walletKeys = CashState.instance.wallets.keys.toList();
    for (var key in walletKeys) {
      walletControllers[key] = TextEditingController();
      _walletFocusNodes[key] = FocusNode();
    }
  }

  @override
  void dispose() {
    cashController.dispose();
    _cashFocusNode.dispose();
    walletControllers.forEach((_, controller) => controller.dispose());
    _walletFocusNodes.forEach((_, node) => node.dispose());
    super.dispose();
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
    
    final walletEntries = walletControllers.entries.toList();

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

              // 🔹 خانة النقدي
              TextField(
                controller: cashController,
                focusNode: _cashFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: walletEntries.isNotEmpty ? TextInputAction.next : TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'نقدي',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (walletEntries.isNotEmpty) {
                    FocusScope.of(context).requestFocus(_walletFocusNodes[walletEntries[0].key]);
                  } else {
                    _startDay();
                  }
                },
              ),

              const SizedBox(height: 12),

              // 🔹 المحافظ
              ...walletEntries.asMap().entries.map((mapEntry) {
                final index = mapEntry.key;
                final walletKey = mapEntry.value.key;
                final controller = mapEntry.value.value;
                final isLast = index == walletEntries.length - 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controller,
                    focusNode: _walletFocusNodes[walletKey],
                    keyboardType: TextInputType.number,
                    textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: walletKey,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (!isLast) {
                        FocusScope.of(context).requestFocus(_walletFocusNodes[walletEntries[index + 1].key]);
                      } else {
                        _startDay();
                      }
                    },
                  ),
                );
              }),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: dayStarted ? null : _startDay,
                  child: const Text('بدء اليوم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
