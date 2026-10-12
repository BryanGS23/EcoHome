import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../repositories/device_repository.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider({required this.repository}) {
    reload();
  }
  final DeviceRepository repository;
  StreamSubscription<List<Device>>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  List<Device> devices = [];
  bool loading = true;
  String? error;
  final _pending = <String>{};
  final Map<String, String> _controlErrors = {};
  bool busy(String id) => _pending.contains(id);
  String? controlError(String id) => _controlErrors[id];
  int activeCount(DeviceType type) =>
      devices.where((d) => d.type == type && d.enabled).length;

  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    loading = true;
    error = null;
    devices = [];
    notifyListeners();
    _subscription = repository.watchDevices().listen(
      (items) {
        if (_disposed || generation != _generation) return;
        devices = List.unmodifiable(items);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object failure) {
        if (_disposed || generation != _generation) return;
        devices = [];
        loading = false;
        error =
            'No se pudieron cargar los dispositivos. Comprueba tu conexión y permisos.';
        notifyListeners();
      },
    );
  }

  Future<bool> control(String id, {bool? enabled, num? value}) async {
    if (_disposed || loading || error != null || busy(id)) return false;
    final matching = devices.where((d) => d.id == id);
    if (matching.isEmpty) return false;
    _pending.add(id);
    _controlErrors.remove(id);
    notifyListeners();
    try {
      await repository.control(matching.single, enabled: enabled, value: value);
      return !_disposed;
    } catch (_) {
      if (!_disposed) {
        _controlErrors[id] =
            'No se pudo guardar el cambio. Revisa la conexión, el estado y los permisos.';
      }
      return false;
    } finally {
      _pending.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _subscription?.cancel();
    super.dispose();
  }
}
