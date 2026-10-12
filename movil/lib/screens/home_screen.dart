import '../providers/energy_provider.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../providers/area_provider.dart';
import '../providers/scene_provider.dart';
import '../widgets/scene_actions.dart';
import 'package:flutter/material.dart';

import '../providers/notification_provider.dart';
import '../widgets/eco_bottom_navigation.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.notifications,
    required this.devices,
    required this.areas,
    required this.scenes,
    required this.energy,
    required this.onNavigate,
  });

  final NotificationProvider notifications;
  final DeviceProvider devices;
  final AreaProvider areas;
  final SceneProvider scenes;
  final EnergyProvider energy;
  final ValueChanged<int> onNavigate;

  bool get _protected {
    final locks = devices.devices
        .where((d) => d.type == DeviceType.lock)
        .toList();
    final cameras = devices.devices
        .where((d) => d.type == DeviceType.camera)
        .toList();
    return locks.isNotEmpty &&
        cameras.isNotEmpty &&
        [...locks, ...cameras].every((d) => d.enabled && d.online);
  }

  String _deviceCount(int value) => devices.loading
      ? 'Cargando…'
      : devices.error != null
      ? 'No disponible'
      : '$value';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              unreadAlerts: notifications.unreadAlerts,
              onOpen: () => onNavigate(7),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.45,
                    children: [
                      _SummaryCard(
                        Icons.devices,
                        'Dispositivos',
                        _deviceCount(devices.devices.length),
                      ),
                      _SummaryCard(
                        Icons.power_settings_new,
                        'Activos',
                        _deviceCount(
                          devices.devices.where((d) => d.enabled).length,
                        ),
                      ),
                      _SummaryCard(
                        Icons.wifi_off,
                        'Sin conexión',
                        _deviceCount(
                          devices.devices.where((d) => !d.online).length,
                        ),
                      ),
                      _SummaryCard(
                        Icons.meeting_room_outlined,
                        'Áreas',
                        areas.loading
                            ? 'Cargando…'
                            : areas.error != null
                            ? 'No disponible'
                            : '${areas.areas.length}',
                      ),
                      _SummaryCard(
                        Icons.lightbulb_outline,
                        'Luces',
                        devices.loading
                            ? 'Cargando…'
                            : devices.error != null
                            ? 'No disponible'
                            : '${devices.activeCount(DeviceType.light)} encendidas',
                      ),
                      _SummaryCard(
                        Icons.videocam_outlined,
                        'Cámaras',
                        devices.loading
                            ? 'Cargando…'
                            : devices.error != null
                            ? 'No disponible'
                            : '${devices.activeCount(DeviceType.camera)} activas',
                      ),
                      _SummaryCard(
                        Icons.shield_outlined,
                        'Seguridad simulada',
                        devices.loading
                            ? 'Cargando…'
                            : devices.error != null
                            ? 'No disponible'
                            : _protected
                            ? 'Protegido'
                            : 'Revisar',
                      ),
                      _SummaryCard(
                        Icons.bolt_outlined,
                        'Energía simulada (7 días)',
                        energy.loading
                            ? 'Cargando…'
                            : energy.error != null
                            ? 'No disponible'
                            : '${energy.week.toStringAsFixed(1)} Wh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Escenas rápidas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SceneActions(provider: scenes),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(3),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Ver energía estimada'),
                  ),
                  const Text(
                    'Totales de muestras simuladas; no son mediciones reales.',
                  ),
                ],
              ),
            ),
            EcoBottomNavigation(currentIndex: 0, onTap: onNavigate),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unreadAlerts, required this.onOpen});
  final VoidCallback onOpen;
  final int unreadAlerts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
    child: Row(
      children: [
        const Icon(Icons.menu, size: 22),
        const Expanded(
          child: Center(
            child: Text(
              'EcoHome',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: onOpen,
          icon: Badge(
            label: Text('$unreadAlerts'),
            isLabelVisible: unreadAlerts > 0,
            child: const Icon(Icons.notifications_none),
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.icon, this.title, this.value);
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => _Panel(
    padding: const EdgeInsets.all(11),
    child: Row(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF333836)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                key: ValueKey('summary-$title'),
                style: const TextStyle(fontSize: 10, color: Color(0xFF5C625E)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD8DCD9)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}
