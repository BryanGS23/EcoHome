import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/repositories/energy_repository.dart';
import 'package:movil/services/firestore_service.dart';
import 'support/fake_admin_firestore.dart';

class PartialFailureService extends FirestoreService {
  PartialFailureService(FakeAdminFirestore db)
    : super(firestore: db, currentUid: () => 'u');
  bool fail = true;
  @override
  Future<int> simulateEnergy(List<String> ids, DateTime time) async {
    if (fail) {
      fail = false;
      await super.simulateEnergy(ids.take(1).toList(), time);
      throw StateError('Conexión interrumpida después del primer dispositivo');
    }
    return super.simulateEnergy(ids, time);
  }
}

void main() {
  late FakeAdminFirestore db;
  setUp(() {
    db = FakeAdminFirestore();
    final stamp = Timestamp.now();
    for (final id in ['a', 'b']) {
      db.documents['devices/$id'] = {
        'name': id,
        'type': 'light',
        'areaId': 'sala',
        'enabled': true,
        'online': true,
        'value': 100,
        'energyConsumption': 40,
        'createdAt': stamp,
        'updatedAt': stamp,
      };
    }
  });
  double total() => db.documents.entries
      .where((e) => e.key.startsWith('energy_records/'))
      .fold(0.0, (accumulated, e) => accumulated + (e.value['consumption'] as num).toDouble());

  test(
    'el servicio real acumula 80, 160 y 200 Wh según el estado actual',
    () async {
      final repo = EnergyRepository(
        service: FirestoreService(firestore: db, currentUid: () => 'u'),
      );
      expect(await repo.simulate(['a', 'b']), 2);
      expect(total(), 80);
      expect(await repo.simulate(['a', 'b']), 2);
      expect(total(), 160);
      db.documents['devices/a']!['enabled'] = false;
      await repo.simulate(['a', 'b']);
      expect(total(), 200);
      db.documents['devices/b']!['online'] = false;
      await repo.simulate(['a', 'b']);
      expect(total(), 200);
    },
  );

  test(
    'un fallo parcial se completa sin duplicar y la siguiente pulsación agrega otra hora',
    () async {
      final repo = EnergyRepository(service: PartialFailureService(db));
      await expectLater(repo.simulate(['a', 'b']), throwsStateError);
      expect(total(), 40);
      expect(repo.hasPendingSimulation, true);
      expect(await repo.simulate(['a', 'b']), 1);
      expect(total(), 80);
      expect(repo.hasPendingSimulation, false);
      await repo.simulate(['a', 'b']);
      expect(total(), 160);
    },
  );
}
