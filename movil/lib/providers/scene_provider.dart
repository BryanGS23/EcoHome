import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/scene.dart';
import '../repositories/scene_repository.dart';

class SceneProvider extends ChangeNotifier {
  SceneProvider({required this.repository}) {
    reload();
  }
  final SceneRepository repository;
  StreamSubscription<List<Scene>>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  List<Scene> scenes = [];
  bool loading = true;
  String? error;
  String? executingId;
  String? message;
  bool executionFailed = false;
  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    loading = true;
    error = null;
    scenes = [];
    notifyListeners();
    _subscription = repository.watchScenes().listen(
      (items) {
        if (_disposed || generation != _generation) return;
        scenes = List.unmodifiable(items);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object failure) {
        if (_disposed || generation != _generation) return;
        scenes = [];
        loading = false;
        error = failure is SceneFailure
            ? failure.message
            : 'No se pudieron cargar las escenas. Revisa tu conexión y permisos.';
        notifyListeners();
      },
    );
  }

  Future<bool> execute(String id) async {
    if (_disposed || executingId != null || loading || error != null) {
      return false;
    }
    final matches = scenes.where((scene) => scene.id == id);
    if (matches.isEmpty) return false;
    executingId = id;
    message = null;
    executionFailed = false;
    notifyListeners();
    try {
      await repository.execute(matches.single);
      if (_disposed) return false;
      message = 'Escena aplicada correctamente.';
      return true;
    } catch (failure) {
      if (!_disposed) {
        executionFailed = true;
        message = failure is SceneFailure
            ? failure.message
            : 'No se pudo aplicar la escena. Revisa la conexión, los dispositivos y los permisos.';
      }
      return false;
    } finally {
      executingId = null;
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
