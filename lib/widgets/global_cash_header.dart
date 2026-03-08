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

    return Container(
      // استخدام Container بدلاً من Card لتقليل الهوامش الإجبارية
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'اجمالي الفلوس: ',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  cashState.totalMoney.toStringAsFixed(1),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 2.2,
              ),
              itemCount: orderedKeys.length,
              itemBuilder: (context, index) {
                final key = orderedKeys[index];
                final value = allBalances[key]!;
                return Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.04),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransferScreen()),
                  );
                },
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('تحويل الفلوس', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
