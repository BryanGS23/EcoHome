import '../models/area.dart';
import '../services/firestore_service.dart';

class AreaRepository {
  AreaRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;
  Stream<List<Area>> watchAreas() => _service.watchAreas().map((docs) {
    final areas = docs.entries
        .map((e) => Area.fromMap(e.key, e.value))
        .toList();
    areas.sort((a, b) => a.name.compareTo(b.name));
    return areas;
  });
}
