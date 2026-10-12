import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/models/scene.dart';
import 'package:movil/models/device.dart';
import 'package:movil/providers/scene_provider.dart';
import 'package:movil/providers/device_provider.dart';
import 'package:movil/repositories/scene_repository.dart';
import 'package:movil/repositories/device_repository.dart';
import 'package:movil/widgets/scene_actions.dart';
import 'support/fake_firestore_service.dart';

Map<String, dynamic> sceneData() => {
  'name': 'Modo Noche',
  'enabled': true,
  'actions': [
    {'deviceId': 'light', 'enabled': false, 'value': 0},
    {'deviceId': 'lock', 'enabled': true},
  ],
  'createdAt': Timestamp.now(),
  'updatedAt': Timestamp.now(),
};
Map<String, dynamic> targetData(DeviceType type) => {
  'name': type.label,
  'type': type.name,
  'areaId': 'sala',
  'enabled': false,
  'value': 0,
  'online': true,
  'energyConsumption': 0,
  'createdAt': Timestamp.now(),
  'updatedAt': Timestamp.now(),
};
void main() {
  late FakeFirestoreService service;
  setUp(() {
    service = FakeFirestoreService();
    service.scenes['night'] = sceneData();
    service.devices['light'] = {
      ...targetData(DeviceType.light),
      'enabled': true,
      'value': 75,
    };
    service.devices['lock'] = targetData(DeviceType.lock);
  });
  tearDown(() => service.dispose());
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  test('Scene serializa acciones con value opcional sin estado active', () {
    final data = sceneData();
    final scene = Scene.fromMap('night', data);
    expect(scene.toMap(), data);
    expect(scene.toMap().containsKey('active'), false);
    expect(scene.actions.last.toMap().containsKey('value'), false);
  });
  test(
    'rechaza acciones vacías, duplicadas, administrativas y value inválido',
    () {
      for (final actions in [
        [],
        [
          {'deviceId': 'd', 'enabled': true},
          {'deviceId': 'd', 'enabled': false},
        ],
        [
          {'deviceId': 'd', 'enabled': true, 'online': true},
        ],
        [
          {'deviceId': 'd', 'enabled': true, 'value': '20'},
        ],
        List.generate(21, (n) => {'deviceId': 'd$n', 'enabled': false}),
      ]) {
        expect(
          () => Scene.fromMap('n', {...sceneData(), 'actions': actions}),
          throwsA(isA<SceneFailure>()),
        );
      }
    },
  );
  test(
    'ejecución múltiple actualiza stream y conserva configuración y campos protegidos',
    () async {
      final repo = SceneRepository(service: service);
      final devices = DeviceProvider(
        repository: DeviceRepository(service: service),
      );
      addTearDown(devices.dispose);
      await tick();
      final before = Map<String, dynamic>.from(service.devices['light']!);
      final definition = Map<String, dynamic>.from(service.scenes['night']!);
      await repo.execute(Scene.fromMap('night', definition));
      await tick();
      expect(devices.devices.firstWhere((d) => d.id == 'light').enabled, false);
      expect(devices.devices.firstWhere((d) => d.id == 'lock').enabled, true);
      for (final key in [
        'name',
        'type',
        'areaId',
        'energyConsumption',
        'online',
        'createdAt',
      ]) {
        expect(service.devices['light']![key], before[key]);
      }
      expect(service.scenes['night'], definition);
    },
  );
  test(
    'fallos inexistente/offline/incompatible/escena deshabilitada no aplican parcialmente',
    () async {
      final repo = SceneRepository(service: service);
      final scene = Scene.fromMap('night', service.scenes['night']!);
      for (final mode in ['missing', 'offline', 'sensor', 'disabled']) {
        service.devices['lock'] = targetData(DeviceType.lock);
        service.scenes['night']!['enabled'] = true;
        if (mode == 'missing') service.devices.remove('lock');
        if (mode == 'offline') service.devices['lock']!['online'] = false;
        if (mode == 'sensor') service.devices['lock']!['type'] = 'sensor';
        if (mode == 'disabled') service.scenes['night']!['enabled'] = false;
        final before = Map<String, dynamic>.from(service.devices['light']!);
        await expectLater(repo.execute(scene), throwsA(isA<SceneFailure>()));
        expect(service.devices['light'], before);
      }
    },
  );
  test('acción fuera de rango se rechaza antes de preparar escrituras', () {
    final scene = Scene.fromMap('n', {
      ...sceneData(),
      'actions': [
        {'deviceId': 'light', 'enabled': true, 'value': 101},
      ],
    });
    expect(
      () => scene.controlUpdates({
        'light': Device.fromMap('light', service.devices['light']!),
      }),
      throwsA(isA<SceneFailure>()),
    );
  });
  test(
    'provider bloquea doble ejecución y comunica éxito/error sin inventar actividad',
    () async {
      final provider = SceneProvider(
        repository: SceneRepository(service: service),
      );
      addTearDown(provider.dispose);
      await tick();
      final pending = Completer<void>();
      service.sceneAction = () => pending.future;
      final operation = provider.execute('night');
      expect(provider.executingId, 'night');
      expect(await provider.execute('night'), false);
      pending.complete();
      expect(await operation, true);
      expect(service.sceneCalls, 1);
      expect(provider.message, 'Escena aplicada correctamente.');
      service.failure = StateError('permission denied');
      expect(await provider.execute('night'), false);
      expect(provider.executionFailed, true);
      expect(provider.executingId, isNull);
    },
  );
  testWidgets(
    'botón de escena muestra carga, evita doble envío y muestra error offline',
    (tester) async {
      final provider = SceneProvider(
        repository: SceneRepository(service: service),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SceneActions(provider: provider)),
        ),
      );
      await tester.pumpAndSettle();
      final pending = Completer<void>();
      service.sceneAction = () => pending.future;
      await tester.tap(find.text('Aplicar'));
      await tester.pump();
      expect(find.text('Aplicando…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      service.devices['lock']!['online'] = false;
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('sin conexión'), findsOneWidget);
      expect(service.devices['light']!['enabled'], true);
    },
  );
}
