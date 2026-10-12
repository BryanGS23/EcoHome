import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:movil/services/firestore_service.dart';
import 'package:movil/models/scene.dart';
import 'package:movil/models/device.dart';
import 'package:movil/models/energy_record.dart';

class FakeFirestoreService implements FirestoreService {
  final alerts = <String, Map<String, dynamic>>{};
  @override
  Stream<Map<String, Map<String, dynamic>>> watchAlerts(String uid) async* {
    Map<String, Map<String, dynamic>> snapshot() =>
        Map.fromEntries(alerts.entries.where((e) => e.value['userId'] == uid));
    yield snapshot();
    yield* homeEvents.stream.map((_) => snapshot());
  }

  @override
  Future<void> markAlertRead(String id) async {
    alerts[id]!['read'] = true;
    homeEvents.add(null);
  }

  @override
  Future<int> checkDeviceAlerts() async => 0;
  final profiles = <String, Map<String, dynamic>>{};
  final events = StreamController<void>.broadcast();
  Object? failure;
  final areas = <String, Map<String, dynamic>>{};
  final devices = <String, Map<String, dynamic>>{};
  final scenes = <String, Map<String, dynamic>>{};
  final energyRecords = <String, Map<String, dynamic>>{};
  final activity = <String, Map<String, dynamic>>{};
  String userId = 'test-uid';
  void _log(String action, String type, String id) {
    activity['a${activity.length}'] = {
      'userId': userId,
      'action': action,
      'entityType': type,
      'entityId': id,
      'description': 'Acción $action sobre $id',
      'createdAt': Timestamp.now(),
    };
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> watchEnergy(DateTime since) async* {
    Map<String, Map<String, dynamic>> snapshot() => Map.fromEntries(
      energyRecords.entries.where(
        (e) => !(e.value['recordedAt'] as Timestamp).toDate().isBefore(since),
      ),
    );
    yield snapshot();
    yield* homeEvents.stream.map((_) => snapshot());
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> watchActivity(String uid) async* {
    Map<String, Map<String, dynamic>> snapshot() {
      final rows =
          activity.entries.where((e) => e.value['userId'] == uid).toList()
            ..sort(
              (a, b) => (b.value['createdAt'] as Timestamp).compareTo(
                a.value['createdAt'] as Timestamp,
              ),
            );
      return Map.fromEntries(rows.take(50));
    }

    yield snapshot();
    yield* homeEvents.stream.map((_) => snapshot());
  }

  @override
  Future<int> simulateEnergy(List<String> ids, DateTime now) async {
    if (failure != null) throw failure!;
    var count = 0;
    for (final id in ids.toSet()) {
      final key = '${id}_${EnergyRecord.dayKey(now)}';
      if (energyRecords.containsKey(key)) continue;
      final device = Device.fromMap(id, devices[id]!);
      final watts = device.enabled && device.online
          ? device.energyConsumption.toDouble()
          : 0.0;
      energyRecords[key] = {
        'deviceId': id,
        'areaId': device.areaId,
        'powerWatts': watts,
        'durationHours': 1,
        'consumption': watts,
        'recordedAt': Timestamp.fromDate(now),
      };
      count++;
    }
    homeEvents.add(null);
    return count;
  }

  int sceneCalls = 0;
  Future<void> Function()? sceneAction;
  @override
  Stream<Map<String, Map<String, dynamic>>> watchScenes() async* {
    yield Map.of(scenes);
    yield* homeEvents.stream.map((_) => Map.of(scenes));
  }

  @override
  Future<void> executeScene(String id) async {
    sceneCalls++;
    if (sceneAction != null) await sceneAction!();
    if (failure != null) throw failure!;
    if (!scenes.containsKey(id)) {
      throw const SceneFailure('La escena ya no existe.');
    }
    final scene = Scene.fromMap(id, scenes[id]!);
    final updates = scene.controlUpdates({
      for (final e in devices.entries) e.key: Device.fromMap(e.key, e.value),
    });
    for (final e in updates.entries) {
      devices[e.key] = {
        ...devices[e.key]!,
        ...e.value,
        'updatedAt': Timestamp.now(),
      };
    }
    _log('scene_executed', 'scene', id);
    homeEvents.add(null);
  }

  final homeEvents = StreamController<void>.broadcast();
  Future<void> Function()? controlAction;
  int controlCalls = 0;

  @override
  Stream<Map<String, Map<String, dynamic>>> watchAreas() async* {
    yield Map.of(areas);
    yield* homeEvents.stream.map((_) => Map.of(areas));
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> watchDevices() async* {
    yield Map.of(devices);
    yield* homeEvents.stream.map((_) => Map.of(devices));
  }

  @override
  Future<void> updateDeviceControls(
    String id, {
    bool? enabled,
    num? value,
  }) async {
    controlCalls++;
    if (controlAction != null) await controlAction!();
    if (failure != null) throw failure!;
    devices[id] = {
      ...devices[id]!,
      'enabled': ?enabled,
      'value': ?value,
      'updatedAt': Timestamp.now(),
    };
    _log('device_control', 'device', id);
    homeEvents.add(null);
  }

  Map<String, dynamic>? created;
  int writes = 0;
  @override
  Future<void> createProfileIfMissing(
    String uid,
    Map<String, dynamic> data,
  ) async {
    if (failure != null) throw failure!;
    if (profiles.containsKey(uid)) return;
    created = data;
    writes++;
    profiles[uid] = {
      ...data,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };
  }

  @override
  Stream<Map<String, dynamic>?> watchProfile(String uid) async* {
    yield profiles[uid];
    yield* events.stream.map((_) => profiles[uid]);
  }

  @override
  Future<void> updateName(String uid, String name) async {
    if (failure != null) throw failure!;
    profiles[uid] = {
      ...profiles[uid]!,
      'name': name,
      'updatedAt': Timestamp.now(),
    };
    events.add(null);
  }

  Future<void> dispose() async {
    await events.close();
    await homeEvents.close();
  }
}
