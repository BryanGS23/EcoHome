import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/scene.dart';
import '../repositories/admin_repository.dart';
import 'user_provider.dart';

class AdminProvider extends ChangeNotifier {
  AdminProvider({required this.user, required this.repository}) {
    user.addListener(_accessChanged);
    _accessChanged();
  }
  final UserProvider user;
  final AdminRepository repository;
  final data = <String, Map<String, Map<String, dynamic>>>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool busy = false, _disposed = false, _authorized = false;
  int _generation = 0;
  String? error;
  bool get allowed => user.isAdmin;
  void _accessChanged() {
    if (_authorized == allowed) return;
    _authorized = allowed;
    final generation = ++_generation;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    data.clear();
    if (allowed) {
      for (final collection in [
        'users',
        'areas',
        'devices',
        'scenes',
        'activity',
      ]) {
        _subscriptions.add(
          repository
              .watch(collection)
              .listen(
                (rows) {
                  if (_disposed || generation != _generation) return;
                  data[collection] = rows;
                  notifyListeners();
                },
                onError: (Object e) {
                  if (_disposed || generation != _generation) return;
                  data.remove(collection);
                  error =
                      'No se pudo cargar $collection. Comprueba permisos y conexión.';
                  notifyListeners();
                },
              ),
        );
      }
    }
    notifyListeners();
  }

  Future<bool> save(
    String collection,
    String? id,
    Map<String, dynamic>? value,
  ) async {
    if (!allowed || busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (collection == 'users' && id == user.uid) {
        throw const AdminFailure('No puedes cambiar tu propio rol ni estado.');
      }
      if (value == null) {
        await repository.delete(collection, id!);
      } else {
        await repository.save(collection, id, value);
      }
      return !_disposed && allowed;
    } catch (e) {
      if (!_disposed) {
        error = e is AdminFailure
            ? e.message
            : e is SceneFailure
            ? e.message
            : 'No se guardó el cambio. Revisa datos, permisos y conexión.';
      }
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    user.removeListener(_accessChanged);
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
