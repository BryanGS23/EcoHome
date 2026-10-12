import 'package:movil/repositories/energy_repository.dart';
import 'package:movil/repositories/activity_repository.dart';
import 'package:movil/repositories/scene_repository.dart';
import 'package:movil/repositories/area_repository.dart';
import 'package:movil/repositories/device_repository.dart';
import 'support/fake_firestore_service.dart';
import 'package:movil/repositories/user_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/main.dart';
import 'package:movil/providers/auth_provider.dart';
import 'package:movil/repositories/auth_repository.dart';
import 'package:movil/providers/notification_provider.dart';
import 'package:movil/repositories/notification_repository.dart';

import 'support/fake_auth_repository.dart';

class _TrackedHomeState extends NotificationProvider {
  _TrackedHomeState(String uid, FakeFirestoreService service)
    : super(
        uid: uid,
        repository: NotificationRepository(service: service),
      );
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  late FakeAuthRepository repository;
  late AuthProvider auth;
  late FakeFirestoreService firestore;
  late List<_TrackedHomeState> homes;
  setUp(() {
    repository = FakeAuthRepository();
    homes = [];
    firestore = FakeFirestoreService();
  });
  tearDown(() async {
    auth.dispose();
    await firestore.dispose();
    await repository.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    auth = AuthProvider(repository: repository);
    await tester.pumpWidget(
      EcoHomeApp(
        authProvider: auth,
        userRepository: UserRepository(service: firestore),
        areaRepository: AreaRepository(service: firestore),
        deviceRepository: DeviceRepository(service: firestore),
        sceneRepository: SceneRepository(service: firestore),
        energyRepository: EnergyRepository(service: firestore),
        activityRepository: ActivityRepository(service: firestore),
        createNotifications: (uid) {
          final home = _TrackedHomeState(uid, firestore);
          homes.add(home);
          return home;
        },
      ),
    );
  }

  testWidgets('splash, login, sesión y logout crean y liberan EcoHome', (
    tester,
  ) async {
    repository.emitInitial = false;
    await mount(tester);
    expect(find.text('Comprobando sesión…'), findsOneWidget);
    expect(homes, isEmpty);
    repository.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(homes, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'persona@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password',
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(homes, hasLength(1));
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('persona@example.test'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(homes.single.disposed, isTrue);
    // Una nueva sesión recibe otro estado y no conserva la pestaña anterior.
    repository.emit(FakeFirebaseUser(uid: 'second-user'));
    await tester.pumpAndSettle();
    expect(homes, hasLength(2));
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(homes.last.disposed, isTrue);
  });

  testWidgets('restauración de sesión abre EcoHome sin pasar por login', (
    tester,
  ) async {
    repository.currentUser = FakeFirebaseUser();
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'navegación Energía simula sin duplicar y Perfil abre actividad propia',
    (tester) async {
      repository.currentUser = FakeFirebaseUser();
      firestore.devices['lamp'] = {
        'name': 'Luz',
        'type': 'light',
        'areaId': 'sala',
        'enabled': true,
        'value': 50,
        'online': true,
        'energyConsumption': 12,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      await firestore.updateDeviceControls('lamp', value: 75);
      await mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Energía').last);
      await tester.pumpAndSettle();
      expect(find.text('Consumo estimado / simulado'), findsOneWidget);
      await tester.tap(find.text('Simular 1 hora'));
      await tester.pumpAndSettle();
      expect(firestore.energyRecords, hasLength(1));
      expect(find.text('12.0 Wh'), findsWidgets);
      await tester.tap(find.text('Simular 1 hora'));
      await tester.pumpAndSettle();
      expect(firestore.energyRecords, hasLength(1));
      expect(find.text('Las muestras de hoy ya existen.'), findsOneWidget);
      await tester.tap(find.text('Perfil').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi actividad'));
      await tester.pumpAndSettle();
      expect(find.text('Tus 50 acciones más recientes'), findsOneWidget);
      expect(find.textContaining('device_control sobre lamp'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Dashboard deriva contadores y ejecuta escena rápida actualizando dispositivos',
    (tester) async {
      repository.currentUser = FakeFirebaseUser();
      for (final id in ['sala', 'patio']) {
        firestore.areas[id] = {
          'name': id,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };
      }
      for (final entry in {
        'luz': 'light',
        'camara': 'camera',
        'otra': 'outlet',
      }.entries) {
        firestore.devices[entry.key] = {
          'name': entry.key,
          'type': entry.value,
          'areaId': 'sala',
          'enabled': entry.key != 'otra',
          'value': 0,
          'energyConsumption': 0,
          'online': entry.key != 'otra',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };
      }
      firestore.scenes['noche'] = {
        'name': 'Noche',
        'enabled': true,
        'actions': [
          {'deviceId': 'luz', 'enabled': false},
        ],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      await mount(tester);
      await tester.pumpAndSettle();
      String? count(String label) =>
          tester.widget<Text>(find.byKey(ValueKey('summary-$label'))).data;
      expect(count('Dispositivos'), '3');
      expect(count('Activos'), '2');
      expect(count('Sin conexión'), '1');
      expect(count('Áreas'), '2');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('execute-noche')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('execute-noche')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('summary-Activos')),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(count('Activos'), '1');
      expect(count('Luces'), '0 encendidas');
      expect(count('Cámaras'), '1 activas');
      expect(firestore.sceneCalls, 1);
      expect(firestore.devices['luz']!['enabled'], false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'desactivación bloquea EcoHome y libera listeners; permite logout',
    (tester) async {
      repository.currentUser = FakeFirebaseUser();
      await mount(tester);
      await tester.pumpAndSettle();
      firestore.profiles['test-uid']!['active'] = false;
      firestore.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Cuenta desactivada'), findsOneWidget);
      expect(find.byTooltip('Notificaciones'), findsNothing);
      expect(homes.single.disposed, isTrue);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    },
  );

  testWidgets('error de perfil impide crear hogar y permite reintentar', (
    tester,
  ) async {
    repository.currentUser = FakeFirebaseUser();
    firestore.failure = StateError('Firestore unavailable');
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo verificar'), findsOneWidget);
    expect(homes, isEmpty);
    firestore.failure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(homes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('perfil muestra rol y estado y permite editar solamente nombre', (
    tester,
  ) async {
    repository.currentUser = FakeFirebaseUser();
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Rol: user'), findsOneWidget);
    expect(find.text('Estado: Activo'), findsOneWidget);
    await tester.tap(find.text('Editar nombre'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Ana García',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Nombre: Ana García'), findsOneWidget);
    expect(firestore.profiles['test-uid']!['role'], 'user');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('registro valida confirmación y entra mediante el stream', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'persona@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'diferente',
    );
    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas deben coincidir.'), findsOneWidget);
    expect(repository.registerCalls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'password',
    );
    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(repository.registerCalls, 1);
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recuperación confirma envío y permite volver a login', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'persona@example.test',
    );
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(repository.resetCalls, 1);
    expect(find.textContaining('Si existe una cuenta'), findsOneWidget);
    expect(homes, isEmpty);
    await tester.tap(find.text('Volver a iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.textContaining('Si existe una cuenta'), findsNothing);
  });

  testWidgets('formulario muestra loading y error y bloquea dobles envíos', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(repository.signInCalls, 0);
    expect(find.text('Escribe un correo electrónico válido.'), findsOneWidget);
    final pending = Completer<void>();
    repository.signInAction = () => pending.future;
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'persona@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password',
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
    pending.completeError(
      const AuthFailure('El correo o la contraseña no son correctos.'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('El correo o la contraseña no son correctos.'),
      findsOneWidget,
    );
    expect(repository.signInCalls, 1);
    expect(homes, isEmpty);
  });

  testWidgets('formulario se desplaza en pantalla pequeña con teclado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byKey(const ValueKey('auth-confirmation')));
    await tester.ensureVisible(find.text('Registrarme'));
    expect(tester.takeException(), isNull);
  });
}
