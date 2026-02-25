import 'package:aimex/services/toast_service.dart';
import 'package:aimex/widgets/selectable_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/cash_state.dart';
import '../../state/day_state.dart';

class StartDayScreen extends StatefulWidget {
  const StartDayScreen({super.key});

  @override
  State<StartDayScreen> createState() => _StartDayScreenState();
}

class _StartDayScreenState extends State<StartDayScreen> {
  late final Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    final cashState = context.read<CashState>();

    controllers = {
      'نقدي': TextEditingController(text: cashState.cash.toString()),
      ...cashState.wallets.map(
            (key, value) =>
            MapEntry(key, TextEditingController(text: value.toString())),
      ),
    };
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startDay() {
    final dayState = context.read<DayState>();

    if (dayState.dayStarted) {
      ToastService.show('اليوم مفتوح بالفعل - لا يمكن البدء مرة أخرى');
      return;
    }

    final cashState = context.read<CashState>();

    final initialValues = <String, double>{};
    controllers.forEach((key, controller) {
      initialValues[key] = double.tryParse(controller.text) ?? 0.0;
    });

    // تحديث الكاش مباشرة بالقيمة النقدية
    cashState.cash = initialValues['نقدي'] ?? 0.0;

    // startDay يستقبل double فقط
    dayState.startDay(initialValues['نقدي'] ?? 0.0);

    ToastService.show('تم بدء اليوم');

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بداية اليوم')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: controllers.length,
                itemBuilder: (context, index) {
                  final key = controllers.keys.elementAt(index);
                  final controller = controllers[key]!;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SelectableTextField(
                      controller: controller,
                      labelText: key,
                      keyboardType: TextInputType.number,
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startDay,
                child: const Text('بدء اليوم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}