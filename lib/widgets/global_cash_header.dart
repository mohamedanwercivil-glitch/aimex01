import 'package:flutter/material.dart';
import '../state/cash_state.dart';
import '../screens/transfer_screen.dart';

class GlobalCashHeader extends StatefulWidget {
  const GlobalCashHeader({super.key});

  @override
  State<GlobalCashHeader> createState() => _GlobalCashHeaderState();
}

class _GlobalCashHeaderState extends State<GlobalCashHeader> {
  @override
  void initState() {
    super.initState();
    CashState.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    CashState.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cashState = CashState.instance;
    final theme = Theme.of(context);

    const walletOrder = [
      'نقدي',
      'فودافون محمد 32',
      'فودافون عمر',
      'انستا محمد',
      'فودافون محمد 57',
      'وي محمد'
    ];

    final allBalances = {
      'نقدي': cashState.cash,
      ...cashState.wallets,
    };

    final orderedKeys = walletOrder.where((key) => allBalances.containsKey(key)).toList();
    final remainingKeys = allBalances.keys.where((key) => !orderedKeys.contains(key)).toList();
    orderedKeys.addAll(remainingKeys);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'اجمالي الفلوس: ${cashState.totalMoney.toStringAsFixed(1)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            const Divider(height: 1),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4.0,
              runSpacing: 0.0,
              alignment: WrapAlignment.center,
              children: orderedKeys.map((key) {
                final value = allBalances[key]!;
                return Chip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text('${key}: ${value.toStringAsFixed(1)}'),
                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.0),
                  labelStyle: theme.textTheme.labelSmall,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 28, // Adjust height of the button
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  textStyle: theme.textTheme.labelMedium,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransferScreen(),
                    ),
                  );
                },
                child: const Text('تحويل الفلوس'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
