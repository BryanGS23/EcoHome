import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    this.onToggle,
    this.onValue,
    this.busy = false,
    this.error,
  });
  final Device device;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<num>? onValue;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final canControl =
        device.online && !busy && device.type != DeviceType.sensor;
    final state = device.type == DeviceType.lock
        ? (device.enabled ? 'Bloqueada' : 'Desbloqueada')
        : (device.enabled ? 'Activo' : 'Inactivo');
    final label = device.type == DeviceType.light
        ? 'Intensidad (%)'
        : device.type == DeviceType.fan
        ? 'Velocidad'
        : 'Temperatura (°C)';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(switch (device.type) {
                DeviceType.light => Icons.lightbulb_outline,
                DeviceType.fan => Icons.air,
                DeviceType.airConditioner => Icons.ac_unit,
                DeviceType.camera => Icons.videocam_outlined,
                DeviceType.lock => Icons.lock_outline,
                DeviceType.television => Icons.tv,
                DeviceType.sensor => Icons.sensors,
                DeviceType.outlet => Icons.power_outlined,
                DeviceType.other => Icons.devices_other,
              }, color: device.enabled ? const Color(0xFF28B86B) : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('${device.type.label} · $state'),
                    Text(device.online ? 'En línea' : 'Sin conexión'),
                  ],
                ),
              ),
              if (device.type != DeviceType.sensor)
                Switch(
                  key: ValueKey('control-${device.id}'),
                  value: device.enabled,
                  onChanged: canControl ? onToggle : null,
                ),
            ],
          ),
          if (device.type.adjustable)
            Row(
              children: [
                Expanded(child: Text(label)),
                DropdownButton<int>(
                  key: ValueKey('value-${device.id}'),
                  value: device.value.toInt(),
                  items: [
                    for (
                      var n = device.type.minimum;
                      n <= device.type.maximum;
                      n++
                    )
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: canControl && device.enabled && onValue != null
                      ? (value) {
                          if (value != null) onValue!(value);
                        }
                      : null,
                ),
              ],
            ),
          if (device.type == DeviceType.sensor)
            Text('Lectura: ${device.value}'),
          if (busy) const Text('Guardando…'),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
