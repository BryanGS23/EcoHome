import 'package:flutter/material.dart';
import '../providers/activity_provider.dart';
import '../widgets/eco_bottom_navigation.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({
    super.key,
    required this.activity,
    required this.onNavigate,
  });
  final ActivityProvider activity;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: activity,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Mi actividad'),
        leading: IconButton(
          onPressed: () => onNavigate(4),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 4,
        onTap: onNavigate,
      ),
      body: activity.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Tus 50 acciones más recientes'),
                if (activity.error != null) ...[
                  Text(activity.error!),
                  TextButton(
                    onPressed: activity.reload,
                    child: const Text('Reintentar'),
                  ),
                ] else if (activity.entries.isEmpty)
                  const Text('Todavía no tienes actividad registrada.')
                else
                  for (final entry in activity.entries)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(entry.description),
                      subtitle: Text(
                        entry.createdAt.toLocal().toString().split('.').first,
                      ),
                    ),
              ],
            ),
    ),
  );
}
