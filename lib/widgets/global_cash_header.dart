import 'package:flutter/material.dart';
import '../state/cash_state.dart';
import '../screens/transfer_screen.dart';

class GlobalCashHeader extends StatefulWidget {
  const GlobalCashHeader({super.key});

  @override
  State<GlobalCashHeader> createState() =>
      _GlobalCashHeaderState();
}

class _GlobalCashHeaderState
    extends State<GlobalCashHeader> {

  @override
  void initState() {
    super.initState();
    CashState.instance.addListener(_refresh);
  }

  void _refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    CashState.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cashState = CashState.instance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.black87,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'إجمالي الفلوس: ${cashState.totalMoney}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'نقدي: ${cashState.cash}',
            style:
            const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: cashState.wallets.entries
                .map(
                  (e) => Text(
                '${e.key}: ${e.value}',
                style: const TextStyle(
                    color: Colors.white70),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const TransferScreen(),
                  ),
                );
              },
              child:
              const Text('تحويل الفلوس'),
            ),
          )
        ],
      ),
    );
  }
}
