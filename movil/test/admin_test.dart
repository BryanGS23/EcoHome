import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/models/scene.dart';
import 'package:movil/models/activity_log.dart';
import 'package:movil/providers/admin_provider.dart';
import 'package:movil/providers/user_provider.dart';
import 'package:movil/repositories/admin_repository.dart';
import 'package:movil/repositories/user_repository.dart';
import 'package:movil/screens/admin_screen.dart';
import 'support/fake_firestore_service.dart';

class MemoryAdminRepository implements AdminRepository {
  final rows = <String, Map<String, Map<String, dynamic>>>{};
  final watched = <String>[];
  final events = StreamController<void>.broadcast();
  int writes = 0;
  Object? failure;
  @override
  Stream<Map<String, Map<String, dynamic>>> watch(String collection) async* {
    watched.add(collection);
    yield rows[collection] ?? {};
    yield* events.stream.map((_) => rows[collection] ?? {});
  }

  @override
  Future<void> save(
    String collection,
    String? id,
    Map<String, dynamic> data,
  ) async {
    if (failure != null) throw failure!;
    writes++;
    (rows[collection] ??= {})[id ?? 'new'] = data;
    events.add(null);
  }

  @override
  Future<void> delete(String collection, String id) async {
    if (failure != null) throw failure!;
    writes++;
    rows[collection]?.remove(id);
    events.add(null);
  }
}

void main() {
  final stamp = Timestamp.fromDate(DateTime.utc(2026));
  Map<String, dynamic> device({String type = 'light', num value = 30}) => {
    'name': 'Luz',
    'type': type,
    'areaId': 'room',
    'enabled': true,
    'online': false,
    'value': value,
    'energyConsumption': 9,
    'createdAt': stamp,
    'updatedAt': stamp,
  };
  Map<String, dynamic> scene({List<Map<String, dynamic>>? actions}) => {
    'name': 'Noche',
    'enabled': false,
    'createdAt': stamp,
    'updatedAt': stamp,
    'actions':
        actions ??
        [
          {'deviceId': 'lamp', 'enabled': false, 'value': 20},
        ],
  };
  final areas = <String, Map<String, dynamic>>{
    'room': {'name': 'Sala'},
  };
  late Map<String, Map<String, dynamic>> devices, scenes;
  setUp(() {
    devices = {'lamp': device()};
    scenes = {'night': scene()};
  });
  void validate(String collection, String id, Map<String, dynamic>? data) =>
      AdminRepository.validate(collection, id, data, areas, devices, scenes);

  test(
    'integridad: área ocupada y dispositivo referenciado no se borran; liberar referencias permite borrar',
    () {
      expect(
        () => validate('areas', 'room', null),
        throwsA(isA<AdminFailure>()),
      );
      expect(
        () => validate('devices', 'lamp', null),
        throwsA(isA<AdminFailure>()),
      );
      scenes.clear();
      expect(() => validate('devices', 'lamp', null), returnsNormally);
      devices.clear();
      expect(() => validate('areas', 'room', null), returnsNormally);
    },
  );
  test('configuración valida área, nombre, consumo finito y rango de tipo', () {
    expect(() => validate('devices', 'lamp', device()), returnsNormally);
    for (final change in <Map<String, dynamic>>[
      {'name': ' '},
      {'areaId': 'missing'},
      {'energyConsumption': -1},
      {'energyConsumption': double.nan},
      {'value': 101},
      {'type': 'invalid'},
    ]) {
      expect(
        () => validate('devices', 'lamp', {...device(), ...change}),
        throwsA(anything),
      );
    }
  });
  test('cambiar tipo no puede romper acciones existentes', () {
    expect(
      () => validate('devices', 'lamp', device(type: 'fan', value: 1)),
      throwsA(isA<SceneFailure>()),
    );
    scenes.clear();
    expect(
      () => validate('devices', 'lamp', device(type: 'fan', value: 1)),
      returnsNormally,
    );
  });
  test('configurar escena offline/deshabilitada es válido; ejecutarla no', () {
    expect(() => validate('scenes', 'night', scene()), returnsNormally);
    expect(
      () => Scene.fromMap('night', scene()).requireAvailable(),
      throwsA(isA<SceneFailure>()),
    );
  });
  test(
    'acciones rechazan ausentes, duplicados, vacías, sensores y valores incompatibles',
    () {
      for (final actions in <List<Map<String, dynamic>>>[
        [],
        [
          {'deviceId': 'missing', 'enabled': true},
        ],
        [
          {'deviceId': 'lamp', 'enabled': true},
          {'deviceId': 'lamp', 'enabled': false},
        ],
        [
          {'deviceId': 'lamp', 'enabled': true, 'value': 101},
        ],
      ]) {
        expect(
          () => validate('scenes', 'night', scene(actions: actions)),
          throwsA(isA<SceneFailure>()),
        );
      }
      devices['lamp'] = device(type: 'sensor', value: 20);
      expect(
        () => validate('scenes', 'night', scene()),
        throwsA(isA<SceneFailure>()),
      );
    },
  );
  test(
    'perfil administrativo no permite identidad, rol desconocido ni campos extra',
    () {
      expect(
        () => validate('users', 'other', {'role': 'admin', 'active': false}),
        returnsNormally,
      );
      for (final changes in [
        {'uid': 'other'},
        {'email': 'new'},
        {'createdAt': stamp},
        {'role': 'owner'},
      ]) {
        expect(
          () => validate('users', 'other', {
            'role': 'user',
            'active': true,
            ...changes,
          }),
          throwsA(isA<AdminFailure>()),
        );
      }
    },
  );
  test('actividad administrativa usa el esquema existente', () {
    for (final action in ['admin_create', 'admin_update', 'admin_delete']) {
      final data = {
        'userId': 'a',
        'action': action,
        'entityType': 'areas',
        'entityId': 'room',
        'description': 'Cambio',
        'createdAt': stamp,
      };
      expect(ActivityLog.fromMap('log', data).toMap(), data);
    }
  });

  late FakeFirestoreService service;
  late UserProvider user;
  late MemoryAdminRepository repository;
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  Future<void> setupProfile({String role = 'admin'}) async {
    service = FakeFirestoreService();
    final profiles = UserRepository(service: service);
    await profiles.ensureProfile('me', 'me@example.test');
    service.profiles['me']!['role'] = role;
    user = UserProvider(
      uid: 'me',
      email: 'me@example.test',
      repository: profiles,
    );
    repository = MemoryAdminRepository();
    await user.load();
    await tick();
    addTearDown(() async {
      user.dispose();
      await service.dispose();
      await repository.events.close();
    });
  }

  test('user no inicia consultas administrativas ni escribe', () async {
    await setupProfile(role: 'user');
    final admin = AdminProvider(user: user, repository: repository);
    addTearDown(admin.dispose);
    await tick();
    expect(admin.allowed, false);
    expect(repository.watched, isEmpty);
    expect(
      await admin.save('users', 'me', {'role': 'admin', 'active': true}),
      false,
    );
    expect(repository.writes, 0);
  });
  test(
    'admin protege propia cuenta y permite cambiar otras; fallo no indica éxito',
    () async {
      await setupProfile();
      final admin = AdminProvider(user: user, repository: repository);
      addTearDown(admin.dispose);
      expect(
        await admin.save('users', 'me', {'role': 'user', 'active': false}),
        false,
      );
      expect(repository.writes, 0);
      expect(
        await admin.save('users', 'other', {'role': 'admin', 'active': true}),
        true,
      );
      repository.failure = const AdminFailure('Error de prueba');
      expect(await admin.save('areas', null, {'name': 'Sala'}), false);
      expect(admin.error, 'Error de prueba');
      expect(admin.busy, false);
      expect(repository.writes, 1);
    },
  );
  for (final change in [
    {'role': 'user'},
    {'active': false},
  ]) {
    test(
      'revocación $change cancela consultas, borra datos y bloquea nuevas escrituras',
      () async {
        await setupProfile();
        repository.rows['users'] = {
          'other': {'name': 'Privado'},
        };
        final admin = AdminProvider(user: user, repository: repository);
        addTearDown(admin.dispose);
        await tick();
        expect(admin.data['users'], isNotEmpty);
        service.profiles['me']!.addAll(change);
        service.events.add(null);
        await tick();
        repository.events.add(null);
        await tick();
        expect(admin.allowed, false);
        expect(admin.data, isEmpty);
        expect(await admin.save('areas', null, {'name': 'Nuevo'}), false);
        expect(repository.writes, 0);
      },
    );
  }
  testWidgets(
    'ruta directa no permite user y editor abierto se bloquea al revocar admin',
    (tester) async {
      await tester.runAsync(() => setupProfile(role: 'user'));
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(user: user, onBack: () {}, repository: repository),
        ),
      );
      expect(find.text('Acceso administrativo revocado.'), findsOneWidget);
      expect(find.text('Administración'), findsNothing);
      await tester.runAsync(() async {
        service.profiles['me']!['role'] = 'admin';
        service.events.add(null);
        await tick();
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áreas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear área'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar'), findsOneWidget);
      await tester.runAsync(() async {
        service.profiles['me']!['role'] = 'user';
        service.events.add(null);
        await tick();
      });
      await tester.pumpAndSettle();
      expect(find.text('Acceso revocado'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
