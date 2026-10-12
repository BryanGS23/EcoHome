import 'package:cloud_firestore/cloud_firestore.dart';

class Area {
  const Area({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, name;
  final DateTime createdAt, updatedAt;
  factory Area.fromMap(String id, Map<String, dynamic> data) {
    if (id.isEmpty ||
        data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      throw const FormatException('Área inválida.');
    }
    return Area(
      id: id,
      name: data['name'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
