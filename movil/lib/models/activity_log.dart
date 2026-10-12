import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.description,
    required this.createdAt,
  });
  final String id, userId, action, entityType, entityId, description;
  final DateTime createdAt;
  static const deviceControl = 'device_control';
  static const sceneExecuted = 'scene_executed';
  factory ActivityLog.fromMap(String id, Map<String, dynamic> data) {
    if ([
          'userId',
          'action',
          'entityType',
          'entityId',
          'description',
        ].any((key) => data[key] is! String) ||
        ![
          deviceControl,
          sceneExecuted,
          'admin_create',
          'admin_update',
          'admin_delete',
        ].contains(data['action']) ||
        data['createdAt'] is! Timestamp) {
      throw const FormatException('Actividad inválida.');
    }
    return ActivityLog(
      id: id,
      userId: data['userId'] as String,
      action: data['action'] as String,
      entityType: data['entityType'] as String,
      entityId: data['entityId'] as String,
      description: data['description'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'action': action,
    'entityType': entityType,
    'entityId': entityId,
    'description': description,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
