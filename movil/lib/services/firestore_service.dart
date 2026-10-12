import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';
import '../models/scene.dart';
import '../models/activity_log.dart';
import '../models/energy_record.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    String Function()? currentUid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ??
           (() =>
               FirebaseAuth.instance.currentUser?.uid ??
               (throw StateError('Sin sesión')));
  final FirebaseFirestore _firestore;
  final String Function() _currentUid;

  Map<String, dynamic> _activity(
    String uid,
    String action,
    String type,
    String id,
    String description,
  ) => {
    'userId': uid,
    'action': action,
    'entityType': type,
    'entityId': id,
    'description': description.length > 300
        ? description.substring(0, 300)
        : description,
    'createdAt': FieldValue.serverTimestamp(),
  };
  Stream<Map<String, Map<String, dynamic>>> watchActivity(String uid) =>
      _watchQuery(
        _firestore
            .collection('activity')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50),
      );
  Stream<Map<String, Map<String, dynamic>>> watchEnergy(DateTime since) =>
      _watchQuery(
        _firestore
            .collection('energy_records')
            .where(
              'recordedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since),
            )
            .orderBy('recordedAt'),
      );

  Future<int> simulateEnergy(List<String> ids, DateTime now) async {
    var created = 0;
    final day = EnergyRecord.dayKey(now);
    // Separate idempotent transactions: retrying completes a partially interrupted sample.
    for (final id in ids.toSet()) {
      created += await _firestore.runTransaction<int>((tx) async {
        final ref = _firestore.collection('energy_records').doc('${id}_$day');
        final existing = await tx.get(ref);
        if (existing.exists) return 0;
        final snapshot = await tx.get(_firestore.collection('devices').doc(id));
        if (!snapshot.exists) throw StateError('Dispositivo inexistente');
        final device = Device.fromMap(id, snapshot.data()!);
        final watts = device.enabled && device.online
            ? device.energyConsumption.toDouble()
            : 0.0;
        tx.set(ref, {
          'deviceId': id,
          'areaId': device.areaId,
          'powerWatts': watts,
          'durationHours': 1,
          'consumption': EnergyRecord.estimateWh(watts, 1),
          'recordedAt': FieldValue.serverTimestamp(),
        });
        return 1;
      });
    }
    return created;
  }

  Stream<Map<String, Map<String, dynamic>>> watchScenes() =>
      _watchCollection('scenes');

  Future<void> executeScene(String id) {
    final uid = _currentUid();
    final activityRef = _firestore.collection('activity').doc();
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(
        _firestore.collection('scenes').doc(id),
      );
      if (!snapshot.exists) throw const SceneFailure('La escena ya no existe.');
      final scene = Scene.fromMap(id, snapshot.data()!);
      scene.requireAvailable();
      final devices = <String, Device>{};
      // All reads and validation precede writes. Retries reread scene + devices.
      for (final action in scene.actions) {
        final doc = await transaction.get(
          _firestore.collection('devices').doc(action.deviceId),
        );
        if (doc.exists) devices[doc.id] = Device.fromMap(doc.id, doc.data()!);
      }
      final updates = scene.controlUpdates(devices);
      for (final entry in updates.entries) {
        transaction.update(_firestore.collection('devices').doc(entry.key), {
          ...entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(
        activityRef,
        _activity(
          uid,
          ActivityLog.sceneExecuted,
          'scene',
          id,
          'Ejecutó escena "${scene.name}"',
        ),
      );
    });
  }

  Stream<Map<String, Map<String, dynamic>>> watchAreas() =>
      _watchCollection('areas');
  Stream<Map<String, Map<String, dynamic>>> watchDevices() =>
      _watchCollection('devices');

  Stream<Map<String, Map<String, dynamic>>> _watchCollection(String path) =>
      _watchQuery(_firestore.collection(path));
  Stream<Map<String, Map<String, dynamic>>> _watchQuery(
    Query<Map<String, dynamic>> query,
  ) => query
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map((snapshot) {
        if (snapshot.metadata.isFromCache) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        return {for (final doc in snapshot.docs) doc.id: doc.data()};
      });

  // Transactions require connectivity; controls are never queued for later offline execution.
  Future<void> updateDeviceControls(String id, {bool? enabled, num? value}) {
    final uid = _currentUid();
    final activityRef = _firestore.collection('activity').doc();
    return _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('devices').doc(id);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('El dispositivo ya no existe.');
      transaction.update(ref, {
        'enabled': ?enabled,
        'value': ?value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        activityRef,
        _activity(
          uid,
          ActivityLog.deviceControl,
          'device',
          id,
          'Cambió "${snapshot.data()!['name']}": ${enabled == null ? '' : 'estado ${enabled ? 'activo' : 'inactivo'} '}${value == null ? '' : 'valor $value'}',
        ),
      );
    });
  }

  Stream<Map<String, Map<String, dynamic>>> watchAlerts(String uid) =>
      _watchQuery(
        _firestore
            .collection('alerts')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(100),
      );

  Future<void> markAlertRead(String id) =>
      _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('alerts').doc(id);
        final doc = await tx.get(ref);
        if (doc.data()?['userId'] != _currentUid()) {
          throw StateError('Alerta ajena');
        }
        tx.update(ref, {'read': true});
      });

  Future<int> checkDeviceAlerts() async {
    final uid = _currentUid();
    final day = EnergyRecord.dayKey(DateTime.now().toUtc());
    final devices = await _firestore
        .collection('devices')
        .get(const GetOptions(source: Source.server));
    var created = 0;
    for (final candidate in devices.docs) {
      if (candidate.data()['online'] != false ||
          !['camera', 'lock'].contains(candidate.data()['type'])) {
        continue;
      }
      created += await _firestore.runTransaction<int>((tx) async {
        final ref = _firestore
            .collection('alerts')
            .doc('${uid}_${candidate.id}_$day');
        final existing = await tx.get(ref);
        final device = await tx.get(candidate.reference);
        if (existing.exists ||
            !device.exists ||
            device.data()?['online'] != false ||
            !['camera', 'lock'].contains(device.data()?['type'])) {
          return 0;
        }
        tx.set(ref, {
          'title': 'Dispositivo sin conexión',
          'message':
              '${device.data()!['name']} está sin conexión (simulación).',
          'type': 'device_offline',
          'deviceId': candidate.id,
          'userId': uid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return 1;
      });
    }
    return created;
  }

  // The transaction requires the server and never overwrites an existing profile.
  Future<void> createProfileIfMissing(String uid, Map<String, dynamic> data) =>
      _firestore.runTransaction((transaction) async {
        final ref = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) transaction.set(ref, data);
      });

  Stream<Map<String, dynamic>?> watchProfile(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      // Do not authorize entry using stale cache or unresolved server timestamps.
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map((snapshot) => snapshot.data());

  Future<void> updateName(String uid, String name) => _firestore
      .collection('users')
      .doc(uid)
      .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});
}
