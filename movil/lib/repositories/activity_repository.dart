import '../models/activity_log.dart';
import '../services/firestore_service.dart';

class ActivityRepository {
  ActivityRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;
  Stream<List<ActivityLog>> watch(String uid) => _service
      .watchActivity(uid)
      .map(
        (docs) => docs.entries
            .map((e) => ActivityLog.fromMap(e.key, e.value))
            .toList(),
      );
}
