import 'package:flutter/material.dart';

class MainButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const MainButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(title),
        onPressed: onTap,
      ),
    );
  }
}
