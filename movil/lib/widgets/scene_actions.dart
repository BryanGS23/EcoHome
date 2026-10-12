import 'package:flutter/material.dart';
import '../providers/scene_provider.dart';

/// Shared execution feedback for the scenes page and dashboard shortcuts.
class SceneActions extends StatelessWidget {
  const SceneActions({super.key, required this.provider});
  final SceneProvider provider;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: provider,
    builder: (context, _) {
      if (provider.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (provider.error != null) {
        return Column(
          children: [
            Text(provider.error!),
            TextButton(
              onPressed: provider.reload,
              child: const Text('Reintentar escenas'),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.scenes.isEmpty) const Text('Todavía no hay escenas.'),
          for (final scene in provider.scenes)
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFD7DBD8)),
              ),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(scene.name),
                subtitle: Text(
                  scene.enabled
                      ? '${scene.actions.length} dispositivos'
                      : 'No disponible',
                ),
                trailing: FilledButton(
                  key: ValueKey('execute-${scene.id}'),
                  onPressed: !scene.enabled || provider.executingId != null
                      ? null
                      : () => provider.execute(scene.id),
                  child: Text(
                    provider.executingId == scene.id ? 'Aplicando…' : 'Aplicar',
                  ),
                ),
              ),
            ),
          if (provider.message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                provider.message!,
                style: TextStyle(
                  color: provider.executionFailed
                      ? Theme.of(context).colorScheme.error
                      : const Color(0xFF16703E),
                ),
              ),
            ),
        ],
      );
    },
  );
}
