import 'package:flutter/material.dart';
import '../models/device.dart';
import '../providers/area_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/eco_screen_header.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({
    super.key,
    required this.areas,
    required this.devices,
    required this.onNavigate,
  });
  final AreaProvider areas;
  final DeviceProvider devices;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([areas, devices]),
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EcoScreenHeader(title: 'Dispositivos', onBack: () => onNavigate(0)),
            Expanded(child: _content()),
            EcoBottomNavigation(currentIndex: 1, onTap: onNavigate),
          ],
        ),
      ),
    ),
  );
  Widget _content() {
    if (areas.loading || devices.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = areas.error ?? devices.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              TextButton(
                onPressed: () {
                  areas.reload();
                  devices.reload();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (areas.areas.isEmpty && devices.devices.isEmpty) {
      return const Center(child: Text('Todavía no hay áreas ni dispositivos.'));
    }
    final knownIds = areas.areas.map((area) => area.id).toSet();
    final orphaned = devices.devices
        .where((d) => !knownIds.contains(d.areaId))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Estados simulados',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        for (final area in areas.areas)
          _areaCard(
            area.id,
            area.name,
            devices.devices.where((d) => d.areaId == area.id).toList(),
          ),
        if (orphaned.isNotEmpty)
          _areaCard('unassigned', 'Área no disponible', orphaned),
      ],
    );
  }

  Widget _areaCard(String id, String name, List<Device> items) => Card(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFD7DBD8)),
    ),
    child: ExpansionTile(
      key: PageStorageKey('area-$id'),
      title: Text(name),
      subtitle: Text('${items.length} dispositivos'),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Sin dispositivos'),
          ),
        for (final device in items)
          DeviceCard(
            key: ValueKey(device.id),
            device: device,
            busy: devices.busy(device.id),
            error: devices.controlError(device.id),
            onToggle: (value) => devices.control(device.id, enabled: value),
            onValue: (value) => devices.control(device.id, value: value),
          ),
      ],
    ),
  );
}
