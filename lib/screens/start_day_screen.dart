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
  
  final FocusNode _cashFocusNode = FocusNode();
  final Map<String, FocusNode> _walletFocusNodes = {};

  @override
  void initState() {
    super.initState();

    // 🔹 وضع رصيد الكاش الحالي كقيمة افتراضية
    cashController.text = CashState.instance.cash.toStringAsFixed(2);

    final walletKeys = CashState.instance.wallets.keys.toList();
    for (var key in walletKeys) {
      // 🔹 وضع رصيد كل محفظة كقيمة افتراضية
      walletControllers[key] = TextEditingController(
        text: CashState.instance.wallets[key]?.toStringAsFixed(2) ?? "0.00"
      );
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

    CashState.instance.setStartOfDay(
      startCash: cash,
      startWallets: wallets,
    );

    DayState.instance.startDay(cash);
    BackgroundService.scheduleEndOfDayTask();

    ToastService.show('تم بدء اليوم بالأرصدة المحددة');

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
              const Text(
                'تأكيد أرصدة بداية اليوم:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'تم وضع الأرصدة الحالية تلقائياً، يمكنك تعديلها إذا كانت مختلفة عن الواقع.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: cashController,
                focusNode: _cashFocusNode,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: walletEntries.isNotEmpty ? TextInputAction.next : TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'رصيد النقدي (كاش)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: walletKey,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.account_balance_wallet),
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
                height: 55,
                child: ElevatedButton(
                  onPressed: dayStarted ? null : _startDay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('بدء اليوم بالأرصدة الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
