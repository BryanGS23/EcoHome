import 'package:movil/repositories/energy_repository.dart';
import 'package:movil/repositories/activity_repository.dart';
import 'package:movil/repositories/scene_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:movil/repositories/area_repository.dart';
import 'package:movil/repositories/device_repository.dart';
import 'support/fake_firestore_service.dart';
import 'package:movil/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/main.dart';
import 'package:movil/repositories/notification_repository.dart';
import 'package:movil/providers/auth_provider.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets('muestra las tres pantallas móviles oficiales', (tester) async {
    final repository = FakeAuthRepository(currentUser: FakeFirebaseUser());
    final auth = AuthProvider(repository: repository);
    addTearDown(() async {
      auth.dispose();
      await repository.dispose();
    });
    final firestore = FakeFirestoreService();
    addTearDown(firestore.dispose);
    for (final name in ['Sala', 'Cocina', 'Recámara', 'Baño', 'Patio']) {
      firestore.areas[name] = {
        'name': name,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
    }
    for (final entry in {
      'modo_noche': 'Modo Noche',
      'ahorro_energia': 'Ahorro de Energía',
    }.entries) {
      firestore.scenes[entry.key] = {
        'name': entry.value,
        'enabled': true,
        'actions': [
          {'deviceId': 'light_sala_1', 'enabled': false},
        ],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
    }
    await tester.pumpWidget(
      EcoHomeApp(
        notificationRepository: NotificationRepository(service: firestore),
        authProvider: auth,
        userRepository: UserRepository(service: firestore),
        areaRepository: AreaRepository(service: firestore),
        deviceRepository: DeviceRepository(service: firestore),
        sceneRepository: SceneRepository(service: firestore),
        energyRepository: EnergyRepository(service: firestore),
        activityRepository: ActivityRepository(service: firestore),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificaciones'), findsOneWidget);

    await tester.tap(find.text('Dispositivos').last);
    await tester.pump();
    expect(find.text('Sala'), findsOneWidget);
    expect(find.text('Patio'), findsOneWidget);

    await tester.tap(find.text('Escenas').first);
    await tester.pump();
    expect(find.text('Modo Noche'), findsOneWidget);
    expect(find.text('Ahorro de Energía'), findsOneWidget);
  });
}
