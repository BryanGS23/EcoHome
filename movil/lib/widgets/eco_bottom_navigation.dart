import 'package:flutter/material.dart';

class EcoBottomNavigation extends StatelessWidget {
  const EcoBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['Inicio', 'Dispositivos', 'Escenas', 'Energía', 'Perfil'];
    const icons = [
      Icons.home_outlined,
      Icons.grid_view_outlined,
      Icons.star_border,
      Icons.bolt_outlined,
      Icons.person_outline,
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE0E2E0))),
        color: Colors.white,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = currentIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[index],
                        size: 20,
                        color: selected
                            ? const Color(0xFF2DBB70)
                            : const Color(0xFF4A504C),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 9,
                          color: selected
                              ? const Color(0xFF2DBB70)
                              : const Color(0xFF4A504C),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
