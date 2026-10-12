import 'package:flutter/material.dart';
import '../providers/notification_provider.dart';
import '../services/push_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.notifications,
    required this.onBack,
    this.push,
  });
  final NotificationProvider notifications;
  final VoidCallback onBack;
  final PushService? push;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([notifications, ?push]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: BackButton(onPressed: onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Alertas simuladas · últimas 100. No representan seguridad física real.',
          ),
          FilledButton.icon(
            onPressed: notifications.busy ? null : notifications.checkDevices,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Comprobar dispositivos'),
          ),
          const Text(
            'Comprueba cámaras y cerraduras sin conexión. No genera push.',
          ),
          if (push != null) ...[
            OutlinedButton(
              onPressed: push!.requesting ? null : push!.enable,
              child: const Text('Activar notificaciones push'),
            ),
            Text(push!.status),
            const Text('Los push de prueba no se guardan como alertas.'),
          ],
          if (notifications.message != null) Text(notifications.message!),
          if (notifications.loading || notifications.busy)
            const LinearProgressIndicator(),
          if (notifications.error != null) ...[
            Text(notifications.error!),
            TextButton(
              onPressed: notifications.reload,
              child: const Text('Reintentar'),
            ),
          ],
          if (!notifications.loading &&
              notifications.error == null &&
              notifications.alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Sin alertas recientes.'),
            ),
          for (final alert in notifications.alerts)
            Card(
              child: ListTile(
                leading: Icon(
                  alert.read
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  color: alert.read
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  alert.title,
                  style: TextStyle(
                    fontWeight: alert.read
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${alert.message}\n${alert.createdAt.toLocal()}\n${alert.read ? 'Leída' : 'No leída'}',
                ),
                trailing: alert.read
                    ? null
                    : IconButton(
                        tooltip: 'Marcar como leída',
                        onPressed: notifications.busy
                            ? null
                            : () => notifications.markRead(alert),
                        icon: const Icon(Icons.done),
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}
