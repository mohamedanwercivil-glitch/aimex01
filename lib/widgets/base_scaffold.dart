import 'package:flutter/material.dart';
import 'global_cash_header.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          const GlobalCashHeader(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
