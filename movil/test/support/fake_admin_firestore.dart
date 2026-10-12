// Test doubles implement the SDK's annotated interfaces; production never does.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

// Small transactional double for the actual AdminService. Authorization itself
// is exercised separately against the Firestore rules emulator.
class FakeAdminFirestore implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  int _ids = 0;
  bool failCommit = false;
  void Function()? beforeFirstCommit;
  int attempts = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final first = _Transaction(this);
    attempts++;
    var result = await transactionHandler(first);
    if (failCommit) throw StateError('Commit failed');
    final conflict = beforeFirstCommit;
    beforeFirstCommit = null;
    if (conflict != null) {
      conflict();
      final retry = _Transaction(this);
      attempts++;
      result = await transactionHandler(retry);
      retry.commit();
    } else {
      first.commit();
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final FakeAdminFirestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(db, '${this.path}/${path ?? 'generated-${db._ids++}'}');
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Query([
    for (final e in db.documents.entries)
      if (e.key.startsWith('$path/') && e.key.split('/').length == 2)
        _Snapshot(e.key, e.value),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db, this.path);
  final FakeAdminFirestore db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.path, Map<String, dynamic>? data)
    : _data = data == null ? null : Map.of(data);
  final String path;
  final Map<String, dynamic>? _data;
  @override
  String get id => path.split('/').last;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic> data() => _data ?? {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Query implements QuerySnapshot<Map<String, dynamic>> {
  _Query(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.db);
  final FakeAdminFirestore db;
  final pending = <String, Map<String, dynamic>?>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (pending.isNotEmpty) throw StateError('Reads after writes');
    return _Snapshot(
          documentReference.path,
          db.documents[documentReference.path],
        )
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    pending[documentReference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    pending[documentReference.path] = {
      ...db.documents[documentReference.path]!,
      ...Map<String, dynamic>.from(data),
    };
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    pending[documentReference.path] = null;
    return this;
  }

  void commit() {
    final now = Timestamp.now();
    for (final e in pending.entries) {
      if (e.value == null) {
        db.documents.remove(e.key);
      } else {
        db.documents[e.key] = {
          for (final field in e.value!.entries)
            field.key: field.value is FieldValue ? now : field.value,
        };
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
