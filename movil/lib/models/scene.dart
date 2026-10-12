import 'package:cloud_firestore/cloud_firestore.dart';
import 'device.dart';

class SceneFailure implements Exception {
  const SceneFailure(this.message);
  final String message;
}

class SceneAction {
  const SceneAction({
    required this.deviceId,
    required this.enabled,
    this.value,
  });
  final String deviceId;
  final bool enabled;
  final num? value;
  factory SceneAction.fromMap(Map<String, dynamic> data) {
    if (data['deviceId'] is! String ||
        (data['deviceId'] as String).isEmpty ||
        (data['deviceId'] as String).contains('/') ||
        data['enabled'] is! bool ||
        data.keys.any(
          (key) => !['deviceId', 'enabled', 'value'].contains(key),
        ) ||
        (data.containsKey('value') &&
            (data['value'] is! num || !(data['value'] as num).isFinite))) {
      throw const SceneFailure('La escena contiene una acción inválida.');
    }
    return SceneAction(
      deviceId: data['deviceId'] as String,
      enabled: data['enabled'] as bool,
      value: data['value'] as num?,
    );
  }
  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'enabled': enabled,
    'value': ?value,
  };
}

class Scene {
  Scene({
    required this.id,
    required this.name,
    required this.enabled,
    required List<SceneAction> actions,
    required this.createdAt,
    required this.updatedAt,
  }) : actions = List.unmodifiable(actions);
  final String id, name;
  final bool enabled;
  final List<SceneAction> actions;
  final DateTime createdAt, updatedAt;
  // Bounded transactions stay comfortably inside Firestore rule-access limits.
  static const maxActions = 20;
  factory Scene.fromMap(String id, Map<String, dynamic> data) {
    if (id.isEmpty ||
        data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        data['enabled'] is! bool ||
        data['actions'] is! List ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      throw const SceneFailure('La configuración de la escena no es válida.');
    }
    final actions = <SceneAction>[];
    for (final raw in data['actions'] as List) {
      if (raw is! Map) {
        throw const SceneFailure('La escena contiene una acción inválida.');
      }
      actions.add(SceneAction.fromMap(Map<String, dynamic>.from(raw)));
    }
    final scene = Scene(
      id: id,
      name: data['name'] as String,
      enabled: data['enabled'] as bool,
      actions: actions,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
    scene.validateActions();
    return scene;
  }
  void validateActions() {
    if (actions.isEmpty ||
        actions.length > maxActions ||
        actions.map((a) => a.deviceId).toSet().length != actions.length) {
      throw const SceneFailure(
        'La escena debe contener entre 1 y 20 dispositivos distintos.',
      );
    }
    for (final action in actions) {
      SceneAction.fromMap(action.toMap());
    }
  }

  void requireAvailable() {
    validateActions();
    if (!enabled) throw const SceneFailure('Esta escena está deshabilitada.');
  }

  Map<String, Map<String, dynamic>> controlUpdates(
    Map<String, Device> devices,
  ) {
    requireAvailable();
    for (final action in actions) {
      final device = devices[action.deviceId];
      if (device != null && !device.online) {
        throw SceneFailure(
          '${device.name} está sin conexión. No se aplicó la escena.',
        );
      }
    }
    return configurationUpdates(devices);
  }

  Map<String, Map<String, dynamic>> configurationUpdates(
    Map<String, Device> devices,
  ) {
    validateActions();
    final updates = <String, Map<String, dynamic>>{};
    for (final action in actions) {
      final device = devices[action.deviceId];
      if (device == null) {
        throw const SceneFailure('Un dispositivo de la escena ya no existe.');
      }
      if (device.type == DeviceType.sensor ||
          (action.value != null &&
              (!device.type.adjustable ||
                  !device.type.acceptsValue(action.value!)))) {
        throw SceneFailure(
          'La acción para ${device.name} no es compatible con su tipo.',
        );
      }
      updates[device.id] = {'enabled': action.enabled, 'value': ?action.value};
    }
    return updates;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'enabled': enabled,
    'actions': actions.map((a) => a.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
