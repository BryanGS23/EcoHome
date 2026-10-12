import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';

class UserRepository {
  UserRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;

  Future<void> ensureProfile(String uid, String email, {String? displayName}) {
    if (uid.isEmpty || email.isEmpty) {
      throw const FormatException(
        'La sesión no contiene una identidad válida.',
      );
    }
    final googleName = displayName?.trim() ?? '';
    final localName = googleName.isNotEmpty
        ? googleName
        : email.split('@').first.trim();
    final name = localName.isEmpty
        ? 'Usuario'
        : localName.substring(0, localName.length > 80 ? 80 : localName.length);
    return _service.createProfileIfMissing(uid, {
      'uid': uid,
      'name': name,
      'email': email,
      'role': UserRole.user.name,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<AppUser?> watchProfile(String uid) => _service
      .watchProfile(uid)
      .map((data) => data == null ? null : AppUser.fromMap(uid, data));

  // No generic update API: role, active, uid and email cannot be edited here.
  Future<void> updateName(String uid, String name) {
    final error = AppUser.validateName(name);
    if (error != null) throw FormatException(error);
    return _service.updateName(uid, name.trim());
  }
}
