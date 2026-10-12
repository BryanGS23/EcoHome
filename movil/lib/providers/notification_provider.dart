import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/eco_alert.dart';
import '../repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required this.uid, required this.repository}) {
    reload();
  }
  final String uid;
  final NotificationRepository repository;
  StreamSubscription<List<EcoAlert>>? _subscription;
  bool _disposed = false, loading = true, busy = false;
  int _generation = 0;
  List<EcoAlert> alerts = [];
  String? error, message;
  int get unreadAlerts => alerts.where((a) => !a.read).length;
  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    loading = true;
    error = null;
    alerts = [];
    notifyListeners();
    _subscription = repository
        .watch(uid)
        .listen(
          (items) {
            if (_disposed || generation != _generation) return;
            alerts = items;
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object e) {
            if (_disposed || generation != _generation) return;
            alerts = [];
            loading = false;
            error =
                'No se pudieron cargar las alertas. Revisa conexión y permisos.';
            notifyListeners();
          },
        );
  }

  Future<void> markRead(EcoAlert alert) async {
    if (alert.userId != uid || alert.read || busy || _disposed) return;
    await _perform(() => repository.markRead(alert.id));
  }

  Future<void> checkDevices() async {
    if (busy || _disposed) return;
    await _perform(() async {
      final count = await repository.checkDevices();
      if (!_disposed) {
        message = count == 0
            ? 'Sin nuevas alertas. Cada dispositivo genera como máximo una por día UTC.'
            : 'Se crearon $count alertas simuladas.';
      }
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      if (!_disposed) {
        message =
            'No se completó la operación. Revisa conexión y permisos; puedes reintentar.';
      }
    } finally {
      busy = false;
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
