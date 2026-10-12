import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/area.dart';
import '../repositories/area_repository.dart';

class AreaProvider extends ChangeNotifier {
  AreaProvider({required this.repository}) {
    reload();
  }
  final AreaRepository repository;
  StreamSubscription<List<Area>>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  List<Area> areas = [];
  bool loading = true;
  String? error;
  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    loading = true;
    error = null;
    areas = [];
    notifyListeners();
    _subscription = repository.watchAreas().listen(
      (items) {
        if (_disposed || generation != _generation) return;
        areas = List.unmodifiable(items);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object failure) {
        if (_disposed || generation != _generation) return;
        areas = [];
        loading = false;
        error =
            'No se pudieron cargar las áreas. Comprueba tu conexión y permisos.';
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
