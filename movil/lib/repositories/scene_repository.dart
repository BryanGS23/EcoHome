import '../models/scene.dart';
import '../services/firestore_service.dart';

class SceneRepository {
  SceneRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;
  Stream<List<Scene>> watchScenes() => _service.watchScenes().map((docs) {
    final scenes = docs.entries
        .map((e) => Scene.fromMap(e.key, e.value))
        .toList();
    scenes.sort((a, b) => a.name.compareTo(b.name));
    return scenes;
  });
  Future<void> execute(Scene scene) {
    scene.requireAvailable();
    return _service.executeScene(scene.id);
  }
}
