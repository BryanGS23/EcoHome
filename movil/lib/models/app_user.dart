import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, admin }

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });
  final String uid, name, email;
  final UserRole role;
  final bool active;
  final DateTime createdAt, updatedAt;

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    return name.isEmpty || name.length > 80
        ? 'Escribe un nombre de entre 1 y 80 caracteres.'
        : null;
  }

  factory AppUser.fromMap(String documentId, Map<String, dynamic> data) {
    final role = UserRole.values.where((r) => r.name == data['role']);
    if (data['uid'] != documentId ||
        documentId.isEmpty ||
        data['name'] is! String ||
        validateName(data['name'] as String) != null ||
        data['email'] is! String ||
        (data['email'] as String).isEmpty ||
        role.length != 1 ||
        data['active'] is! bool ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      throw const FormatException('Perfil inválido.');
    }
    return AppUser(
      uid: documentId,
      name: data['name'] as String,
      email: data['email'] as String,
      role: role.single,
      active: data['active'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role.name,
    'active': active,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
