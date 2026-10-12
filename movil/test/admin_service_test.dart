import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/repositories/admin_repository.dart';
import 'package:movil/services/admin_service.dart';
import 'support/fake_admin_firestore.dart';

void main() {
  late FakeAdminFirestore db;
  late AdminService service;
  final stamp = Timestamp.fromDate(DateTime.utc(2026));
  Map<String, dynamic> device() => {
    'name': 'Luz',
    'type': 'light',
    'areaId': 'room',
    'value': 50,
    'energyConsumption': 9,
    'enabled': true,
    'online': true,
    'createdAt': stamp,
    'updatedAt': stamp,
  };
  Iterable<Map<String, dynamic>> activity() => db.documents.entries
      .where((e) => e.key.startsWith('activity/'))
      .map((e) => e.value);
  setUp(() {
    db = FakeAdminFirestore();
    db.documents['users/admin'] = {
      'role': 'admin',
      'active': true,
      'name': 'Admin',
    };
    db.documents['users/user'] = {
      'role': 'user',
      'active': true,
      'name': 'User',
      'uid': 'user',
      'email': 'u@test.com',
      'createdAt': stamp,
    };
    db.documents['areas/room'] = {
      'name': 'Sala',
      'createdAt': stamp,
      'updatedAt': stamp,
    };
    service = AdminService(firestore: db, currentUid: () => 'admin');
  });
  test(
    'servicio CRUD de catálogo conserva createdAt y registra cada commit',
    () async {
      await service.mutate('areas', null, {'name': 'Nueva'});
      final created = db.documents.keys.singleWhere(
        (k) => k.startsWith('areas/generated-'),
      );
      final date = db.documents[created]!['createdAt'];
      await service.mutate('areas', created.split('/').last, {
        'name': 'Renombrada',
      });
      expect(db.documents[created]!['createdAt'], date);
      await service.mutate('areas', created.split('/').last, null);
      expect(db.documents.containsKey(created), false);
      expect(activity().map((e) => e['action']), [
        'admin_create',
        'admin_update',
        'admin_delete',
      ]);
      expect(db.documents['_admin/catalog']!['revision'], 3);
    },
  );
  test(
    'CRUD dispositivos/escenas valida referencias antes de cualquier escritura',
    () async {
      await service.mutate(
        'devices',
        null,
        device()
          ..remove('createdAt')
          ..remove('updatedAt'),
      );
      final id = db.documents.keys
          .singleWhere((k) => k.startsWith('devices/'))
          .split('/')
          .last;
      await service.mutate('scenes', null, {
        'name': 'Noche',
        'enabled': false,
        'actions': [
          {'deviceId': id, 'enabled': false, 'value': 10},
        ],
      });
      final scene = db.documents.keys
          .singleWhere((k) => k.startsWith('scenes/'))
          .split('/')
          .last;
      await expectLater(
        service.mutate('devices', id, null),
        throwsA(isA<AdminFailure>()),
      );
      await expectLater(
        service.mutate('areas', 'room', null),
        throwsA(isA<AdminFailure>()),
      );
      expect(activity().length, 2);
      await service.mutate('scenes', scene, null);
      await service.mutate('devices', id, null);
      await service.mutate('areas', 'room', null);
      expect(activity().length, 5);
    },
  );
  test(
    'perfiles solo rol/estado ajenos, sin crear/borrar Auth ni identidad',
    () async {
      final before = Map<String, dynamic>.from(db.documents['users/user']!);
      await service.mutate('users', 'user', {'role': 'admin', 'active': false});
      for (final key in ['uid', 'name', 'email', 'createdAt']) {
        expect(db.documents['users/user']![key], before[key]);
      }
      expect(
        activity().single['description'],
        contains('rol admin, activo false'),
      );
      for (final id in ['admin', null]) {
        await expectLater(
          service.mutate('users', id, {'role': 'user', 'active': false}),
          throwsA(isA<AdminFailure>()),
        );
      }
      await expectLater(
        service.mutate('users', 'user', null),
        throwsA(isA<AdminFailure>()),
      );
      expect(activity().length, 1);
    },
  );
  test(
    'admin revocado o inactivo se rechaza dentro de la transacción',
    () async {
      for (final profile in [
        {'role': 'user', 'active': true},
        {'role': 'admin', 'active': false},
      ]) {
        db.documents['users/admin'] = profile;
        await expectLater(
          service.mutate('areas', 'room', null),
          throwsA(isA<AdminFailure>()),
        );
      }
      expect(activity(), isEmpty);
      expect(db.documents.containsKey('areas/room'), true);
    },
  );
  test('fallo de commit no modifica catálogo ni registra éxito', () async {
    db.failCommit = true;
    await expectLater(
      service.mutate('areas', 'room', {'name': 'No guardar'}),
      throwsStateError,
    );
    expect(db.documents['areas/room']!['name'], 'Sala');
    expect(activity(), isEmpty);
  });
  test(
    'reintento por catálogo concurrente vuelve a comprobar referencias',
    () async {
      db.beforeFirstCommit = () => db.documents['devices/new'] = device();
      await expectLater(
        service.mutate('areas', 'room', null),
        throwsA(isA<AdminFailure>()),
      );
      expect(db.attempts, 2);
      expect(db.documents.containsKey('areas/room'), true);
      expect(activity(), isEmpty);
    },
  );
  test('reintento exitoso no duplica evento ni documento creado', () async {
    db.beforeFirstCommit = () {};
    await service.mutate('areas', null, {'name': 'Nueva'});
    expect(db.attempts, 2);
    expect(activity().length, 1);
    expect(db.documents.keys.where((k) => k.startsWith('areas/')).length, 2);
  });
}
