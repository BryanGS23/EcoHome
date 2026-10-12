import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/models/energy_record.dart';
import 'package:movil/models/activity_log.dart';
import 'package:movil/models/scene.dart';
import 'package:movil/models/device.dart';
import 'package:movil/providers/energy_provider.dart';
import 'package:movil/providers/activity_provider.dart';
import 'package:movil/repositories/energy_repository.dart';
import 'package:movil/repositories/activity_repository.dart';
import 'package:movil/repositories/device_repository.dart';
import 'package:movil/repositories/scene_repository.dart';
import 'support/fake_firestore_service.dart';

void main() {
  late FakeFirestoreService service;
  setUp(() {
    service = FakeFirestoreService();
    service.devices['lamp'] = {
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
  });
  tearDown(() => service.dispose());
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  test(
    'potencia por tiempo produce Wh y el registro conserva su unidad y fecha',
    () {
      expect(EnergyRecord.estimateWh(60, 0.5), 30);
      expect(EnergyRecord.estimateWh(1200, 2), 2400);
      final record = EnergyRecord(
        id: 'r',
        deviceId: 'd',
        areaId: 'sala',
        consumption: 12,
        powerWatts: 12,
        recordedAt: DateTime.utc(2026, 9, 25),
      );
      expect(EnergyRecord.fromMap('r', record.toMap()).toMap(), record.toMap());
      expect(
        () => EnergyRecord.fromMap('r', {...record.toMap(), 'consumption': -1}),
        throwsFormatException,
      );
      expect(
        () => EnergyRecord.fromMap('r', {...record.toMap(), 'consumption': 24}),
        throwsFormatException,
      );
    },
  );
  test(
    'muestra diaria idempotente y snapshot apagado/offline da cero',
    () async {
      final now = DateTime.now().toUtc();
      expect(await service.simulateEnergy(['lamp', 'lamp'], now), 1);
      service.devices['lamp']!['energyConsumption'] = 50;
      expect(await service.simulateEnergy(['lamp'], now), 0);
      expect(service.energyRecords.values.single['consumption'], 12);
      service.devices['lamp']!['enabled'] = false;
      await service.simulateEnergy(['lamp'], now.add(const Duration(days: 1)));
      expect(service.energyRecords.values.last['consumption'], 0);
      service.devices['lamp']!['enabled'] = true;
      service.devices['lamp']!['online'] = false;
      await service.simulateEnergy(['lamp'], now.add(const Duration(days: 2)));
      expect(service.energyRecords.values.last['consumption'], 0);
    },
  );
  test(
    'agrupa días UTC, áreas y dispositivos sin rellenar días ni incluir más de siete',
    () async {
      final day = EnergyRecord.dayKey(DateTime.now());
      void record(
        String id,
        String device,
        String area,
        int offset,
        double wh,
      ) {
        service.energyRecords[id] = EnergyRecord(
          id: id,
          deviceId: device,
          areaId: area,
          consumption: wh,
          powerWatts: wh,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(
            (day + offset) * 86400000 + 3600000,
            isUtc: true,
          ),
        ).toMap();
      }

      record('a', 'lamp', 'sala', 0, 12);
      record('b', 'camera', 'patio', 0, 8);
      record('c', 'lamp', 'sala', -3, 10);
      record('old', 'lamp', 'sala', -7, 500);
      record('future', 'lamp', 'sala', 1, 500);
      final provider = EnergyProvider(
        repository: EnergyRepository(service: service),
      );
      addTearDown(provider.dispose);
      await tick();
      expect(provider.today, 20);
      expect(provider.week, 30);
      expect(provider.byDay, {day: 20, day - 3: 10});
      expect(provider.byArea, {'sala': 22, 'patio': 8});
      expect(provider.byDevice, {'lamp': 22, 'camera': 8});
    },
  );
  test(
    'ActivityLog serializa sin credenciales y rechaza acciones desconocidas',
    () {
      final record = ActivityLog(
        id: 'a',
        userId: 'u',
        action: ActivityLog.deviceControl,
        entityType: 'device',
        entityId: 'lamp',
        description: 'Cambió Luz',
        createdAt: DateTime.utc(2026),
      );
      expect(ActivityLog.fromMap('a', record.toMap()).toMap(), record.toMap());
      expect(
        record.toMap().keys,
        unorderedEquals([
          'userId',
          'action',
          'entityType',
          'entityId',
          'description',
          'createdAt',
        ]),
      );
      expect(
        () =>
            ActivityLog.fromMap('a', {...record.toMap(), 'action': 'unknown'}),
        throwsFormatException,
      );
    },
  );
  test(
    'controles de estado y value crean actividad y fallo no crea evento ni cambio',
    () async {
      final repo = DeviceRepository(service: service);
      await repo.control(
        Device.fromMap('lamp', service.devices['lamp']!),
        enabled: false,
      );
      await repo.control(
        Device.fromMap('lamp', service.devices['lamp']!),
        value: 25,
      );
      expect(service.activity, hasLength(2));
      expect(
        service.activity.values.every(
          (e) => e['action'] == ActivityLog.deviceControl,
        ),
        true,
      );
      service.failure = StateError('permission denied');
      await expectLater(
        repo.control(
          Device.fromMap('lamp', service.devices['lamp']!),
          enabled: true,
        ),
        throwsStateError,
      );
      expect(service.devices['lamp']!['enabled'], false);
      expect(service.activity, hasLength(2));
    },
  );
  test(
    'una escena produce un evento y una escena fallida no genera éxitos falsos',
    () async {
      final data = {
        'name': 'Noche',
        'enabled': true,
        'actions': [
          {'deviceId': 'lamp', 'enabled': false},
        ],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      service.scenes['night'] = data;
      final repo = SceneRepository(service: service);
      await repo.execute(Scene.fromMap('night', data));
      expect(service.activity, hasLength(1));
      expect(
        service.activity.values.single['action'],
        ActivityLog.sceneExecuted,
      );
      service.devices['lamp']!['online'] = false;
      await expectLater(
        repo.execute(Scene.fromMap('night', data)),
        throwsA(isA<SceneFailure>()),
      );
      expect(service.activity, hasLength(1));
    },
  );
  test(
    'historial propio reciente limita 50 y se vacía ante error del stream',
    () async {
      for (var n = 0; n < 55; n++) {
        service.activity['a$n'] = {
          'userId': 'test-uid',
          'action': 'device_control',
          'entityType': 'device',
          'entityId': 'lamp',
          'description': 'Acción $n',
          'createdAt': Timestamp.fromDate(
            DateTime.utc(2026).add(Duration(minutes: n)),
          ),
        };
      }
      service.activity['foreign'] = {
        ...service.activity['a0']!,
        'userId': 'other',
      };
      final provider = ActivityProvider(
        repository: ActivityRepository(service: service),
        uid: 'test-uid',
      );
      addTearDown(provider.dispose);
      await tick();
      expect(provider.entries, hasLength(50));
      expect(provider.entries.first.description, 'Acción 54');
      expect(provider.entries.every((e) => e.userId == 'test-uid'), true);
      service.homeEvents.addError(StateError('permission'));
      await tick();
      expect(provider.entries, isEmpty);
      expect(provider.error, isNotNull);
    },
  );
}
