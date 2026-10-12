import 'package:flutter/material.dart';
import '../providers/scene_provider.dart';
import '../widgets/scene_actions.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/eco_screen_header.dart';

class ScenesScreen extends StatelessWidget {
  const ScenesScreen({
    super.key,
    required this.scenes,
    required this.onNavigate,
  });
  final SceneProvider scenes;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          EcoScreenHeader(
            title: 'Automatizaciones',
            onBack: () => onNavigate(0),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SceneActions(provider: scenes),
            ),
          ),
          EcoBottomNavigation(currentIndex: 2, onTap: onNavigate),
        ],
      ),
    ),
  );
}
