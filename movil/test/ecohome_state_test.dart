import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:movil/providers/notification_provider.dart';
import 'package:movil/repositories/notification_repository.dart';
import 'support/fake_firestore_service.dart';

void main() {
  test(
    'la sesión usa alertas propias Firestore y libera su suscripción',
    () async {
      final service = FakeFirestoreService();
      service.alerts['own'] = {
        'userId': 'u',
        'title': 'Alerta',
        'message': 'Simulada',
        'type': 'device_offline',
        'read': false,
        'createdAt': Timestamp.now(),
      };
      service.alerts['other'] = {...service.alerts['own']!, 'userId': 'other'};
      final state = NotificationProvider(
        uid: 'u',
        repository: NotificationRepository(service: service),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.alerts.single.id, 'own');
      await state.markRead(state.alerts.single);
      await Future<void>.delayed(Duration.zero);
      expect(state.alerts.single.read, true);
      expect(service.alerts['other']!['read'], false);
      state.dispose();
      service.homeEvents.add(null);
      await service.dispose();
    },
  );
}
