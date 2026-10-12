import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/models/device.dart';
import 'package:movil/providers/area_provider.dart';
import 'package:movil/providers/device_provider.dart';
import 'package:movil/repositories/area_repository.dart';
import 'package:movil/repositories/device_repository.dart';
import 'package:movil/screens/device_screen.dart';
import 'support/fake_firestore_service.dart';

Map<String, dynamic> deviceData(DeviceType type) => {
  'name': type.label,
  'type': type.name,
  'areaId': 'sala',
  'enabled': true,
  'value': type == DeviceType.sensor ? 22.5 : type.minimum,
  'online': true,
  'energyConsumption': 0,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026)),
};

void main() {
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  test(
    'serializa los nueve tipos y rechaza documentos o controles inválidos',
    () {
      for (final type in DeviceType.values) {
        final map = deviceData(type);
        final device = Device.fromMap('d', map);
        expect(device.toMap(), map);
        expect(device.type, type);
      }
      for (final change in [
        {'type': 'unknown'},
        {'enabled': 'true'},
        {'value': 101},
        {'createdAt': null},
        {'energyConsumption': -1},
      ]) {
        expect(
          () =>
              Device.fromMap('d', {...deviceData(DeviceType.light), ...change}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'control actualiza por stream sin optimismo y bloquea doble envío',
    () async {
      final service = FakeFirestoreService();
      service.devices['d'] = deviceData(DeviceType.light);
      final provider = DeviceProvider(
        repository: DeviceRepository(service: service),
      );
      addTearDown(() async {
        provider.dispose();
        await service.dispose();
      });
      await tick();
      final pending = Completer<void>();
      service.controlAction = () => pending.future;
      final operation = provider.control('d', enabled: false, value: 40);
      expect(provider.busy('d'), true);
      expect(provider.devices.single.enabled, true);
      expect(await provider.control('d', enabled: false), false);
      pending.complete();
      expect(await operation, true);
      await tick();
      expect(provider.devices.single.enabled, false);
      expect(provider.devices.single.value, 40);
      expect(service.controlCalls, 1);
      expect(
        service.devices['d']!['createdAt'],
        deviceData(DeviceType.light)['createdAt'],
      );
    },
  );
  test(
    'fallo de escritura conserva estado y expone error recuperable',
    () async {
      final service = FakeFirestoreService();
      service.devices['d'] = deviceData(DeviceType.light);
      final provider = DeviceProvider(
        repository: DeviceRepository(service: service),
      );
      addTearDown(() async {
        provider.dispose();
        await service.dispose();
      });
      await tick();
      service.failure = StateError('permission-denied');
      expect(await provider.control('d', enabled: false), false);
      expect(provider.controlError('d'), isNotNull);
      expect(provider.devices.single.enabled, true);
      service.failure = null;
      expect(await provider.control('d', enabled: false), true);
      await tick();
      expect(provider.controlError('d'), isNull);
    },
  );
  test(
    'repositorio impide sensores, offline, valores fuera de rango y valor en cerradura',
    () async {
      final service = FakeFirestoreService();
      final repository = DeviceRepository(service: service);
      addTearDown(service.dispose);
      for (final type in [DeviceType.sensor, DeviceType.light]) {
        final device = Device.fromMap('d', {
          ...deviceData(type),
          'online': type == DeviceType.sensor,
        });
        expect(
          () => repository.control(device, enabled: false),
          throwsFormatException,
        );
      }
      expect(
        () => repository.control(
          Device.fromMap('d', deviceData(DeviceType.fan)),
          value: 4,
        ),
        throwsFormatException,
      );
      expect(
        () => repository.control(
          Device.fromMap('d', deviceData(DeviceType.lock)),
          value: 0,
        ),
        throwsFormatException,
      );
      expect(service.controlCalls, 0);
    },
  );
  test(
    'streams reflejan asociación, errores y recuperación y se cancelan al salir',
    () async {
      final service = FakeFirestoreService();
      final devices = DeviceProvider(
        repository: DeviceRepository(service: service),
      );
      final areas = AreaProvider(repository: AreaRepository(service: service));
      await tick();
      expect(devices.devices, isEmpty);
      service.areas['sala'] = {
        'name': 'Sala',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      service.devices['d'] = deviceData(DeviceType.camera);
      service.homeEvents.add(null);
      await tick();
      expect(areas.areas.single.id, devices.devices.single.areaId);
      service.homeEvents.addError(StateError('unavailable'));
      await tick();
      expect(devices.devices, isEmpty);
      expect(devices.error, isNotNull);
      expect(areas.error, isNotNull);
      service.homeEvents.add(null);
      await tick();
      expect(devices.devices, hasLength(1));
      expect(devices.error, isNull);
      devices.dispose();
      areas.dispose();
      await tick();
      expect(service.homeEvents.hasListener, false);
      await service.dispose();
    },
  );
  test('dispose durante control no notifica un provider destruido', () async {
    final service = FakeFirestoreService();
    service.devices['d'] = deviceData(DeviceType.light);
    final provider = DeviceProvider(
      repository: DeviceRepository(service: service),
    );
    await tick();
    final pending = Completer<void>();
    service.controlAction = () => pending.future;
    final operation = provider.control('d', enabled: false);
    provider.dispose();
    pending.complete();
    expect(await operation, false);
    await service.dispose();
  });
  testWidgets(
    'áreas Firestore agrupan controles; sensor y offline no aceptan órdenes',
    (tester) async {
      final service = FakeFirestoreService();
      service.areas['sala'] = {
        'name': 'Sala',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      service.devices['light'] = deviceData(DeviceType.light);
      service.devices['sensor'] = deviceData(DeviceType.sensor);
      service.devices['lock'] = {
        ...deviceData(DeviceType.lock),
        'online': false,
      };
      final devices = DeviceProvider(
        repository: DeviceRepository(service: service),
      );
      final areas = AreaProvider(repository: AreaRepository(service: service));
      addTearDown(() async {
        devices.dispose();
        areas.dispose();
        await service.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceScreen(
            areas: areas,
            devices: devices,
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sala'));
      await tester.pumpAndSettle();
      expect(find.text('Lectura: 22.5'), findsOneWidget);
      expect(find.byKey(const ValueKey('control-sensor')), findsNothing);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('control-lock')))
            .onChanged,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('control-light')));
      await tester.pumpAndSettle();
      expect(service.devices['light']!['enabled'], false);
      expect(tester.takeException(), isNull);
    },
  );
}
