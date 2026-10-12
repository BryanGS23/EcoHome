import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import '../repositories/activity_repository.dart';

class ActivityProvider extends ChangeNotifier {
  ActivityProvider({required this.repository, required this.uid}) {
    reload();
  }
  final ActivityRepository repository;
  final String uid;
  StreamSubscription<List<ActivityLog>>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  bool loading = true;
  String? error;
  List<ActivityLog> entries = [];
  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    loading = true;
    error = null;
    entries = [];
    notifyListeners();
    _subscription = repository
        .watch(uid)
        .listen(
          (items) {
            if (_disposed || generation != _generation) return;
            entries = items;
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object failure) {
            if (_disposed || generation != _generation) return;
            entries = [];
            loading = false;
            error =
                'No se pudo cargar tu actividad. Revisa conexión y permisos.';
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _subscription?.cancel();
    super.dispose();
  }
}
