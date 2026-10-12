import 'package:cloud_firestore/cloud_firestore.dart';

enum DeviceType {
  light,
  fan,
  airConditioner,
  camera,
  lock,
  television,
  sensor,
  outlet,
  other;

  String get label => switch (this) {
    light => 'Luz',
    fan => 'Ventilador',
    airConditioner => 'Aire acondicionado',
    camera => 'Cámara',
    lock => 'Cerradura',
    television => 'Televisión',
    sensor => 'Sensor',
    outlet => 'Enchufe',
    other => 'Otro',
  };
  bool get adjustable => this == light || this == fan || this == airConditioner;
  int get minimum => this == fan
      ? 1
      : this == airConditioner
      ? 16
      : 0;
  int get maximum => this == light
      ? 100
      : this == fan
      ? 3
      : this == airConditioner
      ? 30
      : 0;
  bool acceptsValue(num value) =>
      value.isFinite &&
      (this == sensor ||
          (value == value.roundToDouble() &&
              value >= minimum &&
              value <= maximum));
}

/// Simulated Firestore state. For locks, enabled=true means locked.
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.areaId,
    required this.enabled,
    required this.value,
    required this.energyConsumption,
    required this.online,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, name, areaId;
  final DeviceType type;
  final bool enabled, online;
  final num value, energyConsumption;
  final DateTime createdAt, updatedAt;

  factory Device.fromMap(String id, Map<String, dynamic> data) {
    final types = DeviceType.values.where((type) => type.name == data['type']);
    if (id.isEmpty ||
        data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        data['areaId'] is! String ||
        (data['areaId'] as String).isEmpty ||
        types.length != 1 ||
        data['enabled'] is! bool ||
        data['online'] is! bool ||
        data['value'] is! num ||
        !types.single.acceptsValue(data['value'] as num) ||
        data['energyConsumption'] is! num ||
        !(data['energyConsumption'] as num).isFinite ||
        (data['energyConsumption'] as num) < 0 ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      throw const FormatException('Dispositivo inválido.');
    }
    return Device(
      id: id,
      name: data['name'] as String,
      type: types.single,
      areaId: data['areaId'] as String,
      enabled: data['enabled'] as bool,
      value: data['value'] as num,
      energyConsumption: data['energyConsumption'] as num,
      online: data['online'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.name,
    'areaId': areaId,
    'enabled': enabled,
    'value': value,
    'energyConsumption': energyConsumption,
    'online': online,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
