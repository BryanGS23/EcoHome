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
  bool _viewing = false;
  final _readingIds = <String>{};
  final _confirmedReadIds = <String>{};
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
            alerts = items
                .map((a) => _confirmedReadIds.contains(a.id) ? a.asRead() : a)
                .toList();
            loading = false;
            error = null;
            notifyListeners();
            _readVisibleAlerts();
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
    if (alert.userId != uid ||
        alert.read ||
        _disposed ||
        !_readingIds.add(alert.id)) {
      return;
    }
    try {
      await repository.markRead(alert.id);
      if (_disposed) return;
      _confirmedReadIds.add(alert.id);
      message = null;
      alerts = alerts.map((a) => a.id == alert.id ? a.asRead() : a).toList();
      notifyListeners();
    } catch (_) {
      if (!_disposed) {
        message =
            'No se pudo marcar la alerta como leída. Revisa la conexión y vuelve a intentarlo.';
        notifyListeners();
      }
    } finally {
      _readingIds.remove(alert.id);
    }
  }

  void setViewing(bool viewing) {
    _viewing = viewing;
    if (viewing) _readVisibleAlerts();
  }

  void _readVisibleAlerts() {
    if (!_viewing || _disposed) return;
    for (final alert in alerts.where((a) => !a.read).toList()) {
      unawaited(markRead(alert));
    }
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
