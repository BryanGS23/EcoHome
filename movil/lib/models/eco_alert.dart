import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType { deviceOffline }

class EcoAlert {
  const EcoAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.userId,
    required this.type,
    required this.createdAt,
    required this.read,
  });
  final String id, title, message, userId;
  final AlertType type;
  final DateTime createdAt;
  final bool read;
  factory EcoAlert.fromMap(String id, Map<String, dynamic> data) {
    if (data['type'] != 'device_offline' ||
        data['title'] is! String ||
        data['message'] is! String ||
        data['userId'] is! String ||
        data['read'] is! bool ||
        data['createdAt'] is! Timestamp) {
      throw const FormatException('Alerta inválida');
    }
    return EcoAlert(
      id: id,
      title: data['title'],
      message: data['message'],
      userId: data['userId'],
      type: AlertType.deviceOffline,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      read: data['read'],
    );
  }
}
