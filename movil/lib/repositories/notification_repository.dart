import '../models/eco_alert.dart';
import '../services/firestore_service.dart';

class NotificationRepository {
  NotificationRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;
  Stream<List<EcoAlert>> watch(String uid) => _service
      .watchAlerts(uid)
      .map(
        (docs) =>
            docs.entries.map((e) => EcoAlert.fromMap(e.key, e.value)).toList(),
      );
  Future<void> markRead(String id) => _service.markAlertRead(id);
  Future<int> checkDevices() => _service.checkDeviceAlerts();
}
