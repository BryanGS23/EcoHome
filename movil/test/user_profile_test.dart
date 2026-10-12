import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/models/app_user.dart';
import 'package:movil/providers/user_provider.dart';
import 'package:movil/repositories/user_repository.dart';
import 'support/fake_firestore_service.dart';

void main() {
  late FakeFirestoreService service;
  late UserRepository repository;
  setUp(() {
    service = FakeFirestoreService();
    repository = UserRepository(service: service);
  });
  tearDown(() => service.dispose());
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('perfil serializa timestamps y ambos roles sin perder datos', () {
    for (final role in UserRole.values) {
      final user = AppUser(
        uid: 'u',
        name: 'Ana',
        email: 'a@test.com',
        role: role,
        active: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 9),
      );
      expect(AppUser.fromMap('u', user.toMap()).toMap(), user.toMap());
    }
  });
  test('rechaza rol desconocido, UID ajeno y timestamps inválidos', () async {
    await repository.ensureProfile('u', 'a@test.com');
    final data = service.profiles['u']!;
    for (final change in [
      {'role': 'owner'},
      {'uid': 'other'},
      {'createdAt': null},
      {'active': 'true'},
    ]) {
      expect(
        () => AppUser.fromMap('u', {...data, ...change}),
        throwsFormatException,
      );
    }
  });
  test('cuenta nueva o antigua sin documento crea solo user activo', () async {
    await repository.ensureProfile('u', 'ana@test.com');
    expect(
      service.created!.keys,
      unorderedEquals([
        'uid',
        'name',
        'email',
        'role',
        'active',
        'createdAt',
        'updatedAt',
      ]),
    );
    expect(service.created!['uid'], 'u');
    expect(service.created!['name'], 'ana');
    expect(service.created!['role'], 'user');
    expect(service.created!['active'], true);
    expect(service.created!['createdAt'], isA<FieldValue>());
    await repository.ensureProfile(
      'google',
      'google@test.com',
      displayName: '  Nombre Google  ',
    );
    expect(service.profiles['google']!['name'], 'Nombre Google');
    expect(service.profiles['google']!['role'], 'user');
    expect(service.profiles['google']!['active'], true);
  });
  test(
    'migración repetida conserva admin inactivo y todos sus datos',
    () async {
      await repository.ensureProfile('u', 'ana@test.com');
      service.profiles['u']!['role'] = 'admin';
      service.profiles['u']!['active'] = false;
      final before = Map<String, dynamic>.from(service.profiles['u']!);
      await repository.ensureProfile(
        'u',
        'changed@test.com',
        displayName: 'Otro nombre Google',
      );
      expect(service.profiles['u'], before);
      expect(service.writes, 1);
    },
  );
  test(
    'edición solo cambia nombre y fecha, nunca identidad rol o estado',
    () async {
      await repository.ensureProfile('u', 'ana@test.com');
      final before = Map<String, dynamic>.from(service.profiles['u']!);
      await repository.updateName('u', '  Ana García  ');
      expect(service.profiles['u']!['name'], 'Ana García');
      for (final key in ['uid', 'email', 'role', 'active', 'createdAt']) {
        expect(service.profiles['u']![key], before[key]);
      }
      expect(() => repository.updateName('u', '   '), throwsFormatException);
      expect(() => repository.updateName('u', 'x' * 81), throwsFormatException);
    },
  );
  test(
    'provider carga activo, refleja admin e inactivo y bloquea edición',
    () async {
      final provider = UserProvider(
        uid: 'u',
        email: 'ana@test.com',
        repository: repository,
      );
      addTearDown(provider.dispose);
      expect(provider.status, ProfileStatus.loading);
      await provider.load();
      await tick();
      expect(provider.status, ProfileStatus.ready);
      service.profiles['u']!['role'] = 'admin';
      service.profiles['u']!['active'] = false;
      service.events.add(null);
      await tick();
      expect(provider.profile!.role, UserRole.admin);
      expect(provider.status, ProfileStatus.inactive);
      expect(await provider.updateName('Otro'), false);
    },
  );
  test('error Firestore bloquea acceso y reintento recupera perfil', () async {
    final provider = UserProvider(
      uid: 'u',
      email: 'ana@test.com',
      repository: repository,
    );
    addTearDown(provider.dispose);
    service.failure = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await provider.load();
    expect(provider.status, ProfileStatus.error);
    expect(provider.profile, isNull);
    service.failure = null;
    await provider.load();
    await tick();
    expect(provider.status, ProfileStatus.ready);
    service.events.addError(StateError('network'));
    await tick();
    expect(provider.status, ProfileStatus.error);
    expect(provider.profile, isNull);
  });
  test(
    'documento eliminado tiene estado missing sin recreación silenciosa',
    () async {
      final provider = UserProvider(
        uid: 'u',
        email: 'ana@test.com',
        repository: repository,
      );
      addTearDown(provider.dispose);
      await provider.load();
      await tick();
      service.profiles.remove('u');
      service.events.add(null);
      await tick();
      expect(provider.status, ProfileStatus.missing);
      expect(service.writes, 1);
    },
  );
  test('fallo de edición se muestra sin inventar un nombre guardado', () async {
    final provider = UserProvider(
      uid: 'u',
      email: 'ana@test.com',
      repository: repository,
    );
    addTearDown(provider.dispose);
    await provider.load();
    await tick();
    service.failure = StateError('offline');
    expect(await provider.updateName('Ana'), false);
    expect(provider.editError, isNotNull);
    expect(provider.profile!.name, 'ana');
  });
}
