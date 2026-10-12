import 'package:flutter/material.dart';
import '../providers/energy_provider.dart';
import '../providers/device_provider.dart';
import '../providers/area_provider.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/eco_screen_header.dart';

class EnergyScreen extends StatelessWidget {
  const EnergyScreen({
    super.key,
    required this.energy,
    required this.devices,
    required this.areas,
    required this.onNavigate,
  });
  final EnergyProvider energy;
  final DeviceProvider devices;
  final AreaProvider areas;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([energy, devices, areas]),
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EcoScreenHeader(title: 'Energía', onBack: () => onNavigate(0)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Consumo estimado / simulado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Muestras de 1 hora con el estado actual; una por dispositivo y día UTC. No representan medición real ni consumo de 24 horas.',
                  ),
                  FilledButton(
                    onPressed:
                        energy.saving ||
                            devices.loading ||
                            devices.error != null ||
                            devices.devices.isEmpty
                        ? null
                        : () => energy.simulate(
                            devices.devices.map((d) => d.id).toList(),
                          ),
                    child: Text(
                      energy.saving ? 'Simulando…' : 'Simular 1 hora',
                    ),
                  ),
                  if (energy.message != null) Text(energy.message!),
                  if (energy.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (energy.error != null) ...[
                    Text(energy.error!),
                    TextButton(
                      onPressed: energy.reload,
                      child: const Text('Reintentar'),
                    ),
                  ] else ...[
                    _line('Hoy (UTC)', energy.today),
                    _line('Últimos 7 días', energy.week),
                    const SizedBox(height: 16),
                    const Text(
                      'Historial diario (Wh)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (energy.records.isEmpty)
                      const Text(
                        'Todavía no hay muestras. Los días sin datos no se completan artificialmente.',
                      ),
                    ..._chart(),
                    const SizedBox(height: 16),
                    const Text(
                      'Por área — últimos 7 días',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final entry in energy.byArea.entries)
                      _line(
                        areas.areas
                                .where((a) => a.id == entry.key)
                                .firstOrNull
                                ?.name ??
                            entry.key,
                        entry.value,
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Por dispositivo — últimos 7 días',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final entry in energy.byDevice.entries)
                      _line(
                        devices.devices
                                .where((d) => d.id == entry.key)
                                .firstOrNull
                                ?.name ??
                            entry.key,
                        entry.value,
                      ),
                  ],
                ],
              ),
            ),
            EcoBottomNavigation(currentIndex: 3, onTap: onNavigate),
          ],
        ),
      ),
    ),
  );
  Widget _line(String label, double value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text('${value.toStringAsFixed(1)} Wh'),
  );
  List<Widget> _chart() {
    final days = energy.byDay.keys.toList()..sort();
    final max = energy.byDay.values.fold<double>(1, (a, b) => a > b ? a : b);
    return [
      for (final day in days)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true).toIso8601String().substring(0, 10)}: ${energy.byDay[day]!.toStringAsFixed(1)} Wh',
              ),
              LinearProgressIndicator(
                value: energy.byDay[day]! / max,
                minHeight: 12,
              ),
            ],
          ),
        ),
    ];
  }
}
