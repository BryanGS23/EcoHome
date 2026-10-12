import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/energy_record.dart';
import '../repositories/energy_repository.dart';

class EnergyProvider extends ChangeNotifier {
  EnergyProvider({required this.repository}) {
    reload();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (EnergyRecord.dayKey(DateTime.now()) != _day) reload();
    });
  }
  final EnergyRepository repository;
  StreamSubscription<List<EnergyRecord>>? _subscription;
  Timer? _timer;
  bool _disposed = false;
  int _generation = 0;
  int _day = EnergyRecord.dayKey(DateTime.now());
  List<EnergyRecord> records = [];
  bool loading = true, saving = false;
  String? error, message;
  double get today => byDay[_day] ?? 0;
  double get week => records
      .where(
        (r) =>
            EnergyRecord.dayKey(r.recordedAt) >= _day - 6 &&
            EnergyRecord.dayKey(r.recordedAt) <= _day,
      )
      .fold(0, (sum, r) => sum + r.consumption);
  Map<K, double> _group<K>(K Function(EnergyRecord) key) {
    final result = <K, double>{};
    for (final r in records) {
      final day = EnergyRecord.dayKey(r.recordedAt);
      if (day < _day - 6 || day > _day) continue;
      result.update(
        key(r),
        (n) => n + r.consumption,
        ifAbsent: () => r.consumption,
      );
    }
    return result;
  }

  Map<int, double> get byDay =>
      _group((r) => EnergyRecord.dayKey(r.recordedAt));
  Map<String, double> get byArea => _group((r) => r.areaId);
  Map<String, double> get byDevice => _group((r) => r.deviceId);
  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    _day = EnergyRecord.dayKey(DateTime.now());
    loading = true;
    error = null;
    records = [];
    notifyListeners();
    _subscription = repository
        .watch(
          DateTime.fromMillisecondsSinceEpoch(
            (_day - 6) * 86400000,
            isUtc: true,
          ),
        )
        .listen(
          (items) {
            if (_disposed || generation != _generation) return;
            records = items;
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object failure) {
            if (_disposed || generation != _generation) return;
            records = [];
            loading = false;
            error = 'No se pudo cargar la energía. Revisa conexión y permisos.';
            notifyListeners();
          },
        );
  }

  Future<void> simulate(List<String> ids) async {
    if (_disposed || saving || ids.isEmpty) return;
    saving = true;
    message = null;
    notifyListeners();
    try {
      final count = await repository.simulate(ids);
      if (!_disposed) {
        message = count == 0
            ? 'Las muestras de hoy ya existen.'
            : 'Se guardaron $count muestras simuladas.';
      }
    } catch (_) {
      if (!_disposed) {
        message =
            'No se pudo completar la simulación. Revisa red, permisos y reloj del teléfono; puedes reintentar sin duplicar.';
      }
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
