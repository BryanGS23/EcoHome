import 'package:flutter/material.dart';

class EcoScreenHeader extends StatelessWidget {
  const EcoScreenHeader({super.key, required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 55,
    child: Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.add, size: 22)),
      ],
    ),
  );
}
