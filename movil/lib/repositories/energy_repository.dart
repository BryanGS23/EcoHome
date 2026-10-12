import '../models/energy_record.dart';
import '../services/firestore_service.dart';

class EnergyRepository {
  EnergyRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;
  Stream<List<EnergyRecord>> watch(DateTime since) => _service
      .watchEnergy(since)
      .map(
        (docs) => docs.entries
            .map((e) => EnergyRecord.fromMap(e.key, e.value))
            .toList(),
      );
  Future<int> simulate(List<String> ids) =>
      _service.simulateEnergy(ids, DateTime.now().toUtc());
}
