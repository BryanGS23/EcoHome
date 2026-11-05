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
  DateTime? _pendingTime;
  DateTime? _lastTime;
  List<String>? _pendingIds;
  bool get hasPendingSimulation => _pendingTime != null;

  Future<int> simulate(List<String> ids) async {
    if (_pendingTime == null) {
      var time = DateTime.now().toUtc();
      if (_lastTime != null && !time.isAfter(_lastTime!)) {
        time = _lastTime!.add(const Duration(microseconds: 1));
      }
      _lastTime = _pendingTime = time;
      _pendingIds = ids.toSet().toList();
    }
    // Keep the operation ID on failure so a partial retry cannot add another hour.
    final count = await _service.simulateEnergy(_pendingIds!, _pendingTime!);
    _pendingTime = null;
    _pendingIds = null;
    return count;
  }
}
