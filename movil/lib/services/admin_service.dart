import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/admin_repository.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore, String Function()? currentUid})
    : _db = firestore ?? FirebaseFirestore.instance,
      _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser!.uid);
  final FirebaseFirestore _db;
  final String Function() _uid;
  static const collections = [
    'users',
    'areas',
    'devices',
    'scenes',
    'activity',
  ];
  Stream<Map<String, Map<String, dynamic>>> watch(String collection) {
    if (!collections.contains(collection)) {
      throw const AdminFailure('Colección no permitida.');
    }
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (collection == 'activity') {
      query = query.orderBy('createdAt', descending: true).limit(100);
    }
    return query
        .snapshots(includeMetadataChanges: true)
        .where((s) => !s.metadata.hasPendingWrites)
        .map((s) {
          if (s.metadata.isFromCache) {
            throw const AdminFailure(
              'No se pudo verificar el acceso con el servidor.',
            );
          }
          return {for (final d in s.docs) d.id: d.data()};
        });
  }

  Future<void> mutate(
    String collection,
    String? id,
    Map<String, dynamic>? data,
  ) async {
    if (!collections.take(4).contains(collection) ||
        (collection == 'users' && (id == null || data == null))) {
      throw const AdminFailure('Operación no permitida.');
    }
    final uid = _uid();
    if (collection == 'users' && id == uid) {
      throw const AdminFailure('No puedes cambiar tu propio rol ni estado.');
    }
    final ref = id == null
        ? _db.collection(collection).doc()
        : _db.collection(collection).doc(id);
    final event = _db.collection('activity').doc();
    final lock = _db.collection('_admin').doc('catalog');
    await _db.runTransaction((tx) async {
      final profile = await tx.get(_db.collection('users').doc(uid));
      if (profile.data()?['role'] != 'admin' ||
          profile.data()?['active'] != true) {
        throw const AdminFailure('Se requiere un administrador activo.');
      }
      // Read before server queries: every catalog writer changes this document.
      // Concurrent admin transactions retry all queries after a conflicting commit.
      final revision = await tx.get(lock);
      final current = await tx.get(ref);
      if (id != null && !current.exists) {
        throw const AdminFailure('El elemento ya no existe.');
      }
      final catalogs = <String, Map<String, Map<String, dynamic>>>{};
      for (final path in ['areas', 'devices', 'scenes']) {
        final snapshot = await _db
            .collection(path)
            .get(const GetOptions(source: Source.server));
        catalogs[path] = {for (final doc in snapshot.docs) doc.id: doc.data()};
      }
      AdminRepository.validate(
        collection,
        ref.id,
        data,
        catalogs['areas']!,
        catalogs['devices']!,
        catalogs['scenes']!,
      );
      if (data == null) {
        tx.delete(ref);
      } else if (collection == 'users') {
        tx.update(ref, {...data, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        tx.set(ref, {
          ...data,
          'createdAt':
              current.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(lock, {
        'revision': (revision.data()?['revision'] as int? ?? 0) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final action = data == null
          ? 'admin_delete'
          : current.exists
          ? 'admin_update'
          : 'admin_create';
      final label = data?['name'] ?? current.data()?['name'] ?? ref.id;
      tx.set(event, {
        'userId': uid,
        'action': action,
        'entityType': collection,
        'entityId': ref.id,
        'description':
            '${data == null
                ? 'Eliminó'
                : current.exists
                ? 'Actualizó'
                : 'Creó'} $collection: $label${collection == 'users' ? ' · rol ${data?['role']}, activo ${data?['active']}' : ''}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
