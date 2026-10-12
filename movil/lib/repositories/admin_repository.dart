import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/device.dart';
import '../models/scene.dart';
import '../services/admin_service.dart';

class AdminFailure implements Exception {
  const AdminFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminRepository {
  AdminRepository({AdminService? service})
    : _service = service ?? AdminService();
  final AdminService _service;
  Stream<Map<String, Map<String, dynamic>>> watch(String collection) =>
      _service.watch(collection);
  Future<void> save(String collection, String? id, Map<String, dynamic> data) =>
      _service.mutate(collection, id, data);
  Future<void> delete(String collection, String id) =>
      _service.mutate(collection, id, null);

  // Also called inside the transaction with fresh references, never just by forms.
  static void validate(
    String collection,
    String id,
    Map<String, dynamic>? data,
    Map<String, Map<String, dynamic>> areas,
    Map<String, Map<String, dynamic>> devices,
    Map<String, Map<String, dynamic>> scenes,
  ) {
    if (data == null) {
      if (collection == 'areas' &&
          devices.values.any((d) => d['areaId'] == id)) {
        throw const AdminFailure(
          'Primero reasigna o elimina los dispositivos del área.',
        );
      }
      if (collection == 'devices' &&
          scenes.values.any(
            (s) => (s['actions'] as List).any((a) => a['deviceId'] == id),
          )) {
        throw const AdminFailure(
          'Primero elimina este dispositivo de las escenas que lo utilizan.',
        );
      }
      return;
    }
    if (collection == 'users') {
      if (data.keys.any((k) => !['role', 'active'].contains(k)) ||
          !['user', 'admin'].contains(data['role']) ||
          data['active'] is! bool) {
        throw const AdminFailure('Solo se permite cambiar rol y estado.');
      }
      return;
    }
    if (data['name'] is! String || AppUser.validateName(data['name']) != null) {
      throw const AdminFailure('El nombre debe tener entre 1 y 80 caracteres.');
    }
    final stamped = {
      ...data,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };
    if (collection == 'devices') {
      final device = Device.fromMap(id, stamped);
      if (!areas.containsKey(device.areaId)) {
        throw const AdminFailure('Selecciona un área existente.');
      }
      if (device.energyConsumption > 100000) {
        throw const AdminFailure('El consumo máximo es 100000 W.');
      }
      // A type change must not invalidate an existing scene.
      final updated = {...devices, id: stamped};
      for (final entry in scenes.entries) {
        if ((entry.value['actions'] as List).any((a) => a['deviceId'] == id)) {
          _validateScene(entry.key, entry.value, updated);
        }
      }
    }
    if (collection == 'scenes') _validateScene(id, stamped, devices);
  }

  static void _validateScene(
    String id,
    Map<String, dynamic> data,
    Map<String, Map<String, dynamic>> devices,
  ) {
    final scene = Scene.fromMap(id, data);
    scene.configurationUpdates({
      for (final e in devices.entries) e.key: Device.fromMap(e.key, e.value),
    });
  }
}
