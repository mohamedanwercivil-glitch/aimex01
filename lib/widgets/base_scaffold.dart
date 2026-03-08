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
    // إذا كان العنوان فارغاً، نخفي الـ AppBar تماماً
    final bool showAppBar = title.isNotEmpty;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // إخفاء الكيبورد والقوائم عند الضغط في أي مكان فارغ
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              const GlobalCashHeader(),
              Expanded(
                child: body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
