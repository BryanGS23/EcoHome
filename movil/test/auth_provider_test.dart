import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil/providers/auth_provider.dart';
import 'package:movil/repositories/auth_repository.dart';

import 'support/fake_auth_repository.dart';

Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuthRepository repository;
  late AuthProvider auth;
  setUp(() {
    repository = FakeAuthRepository();
    auth = AuthProvider(repository: repository);
  });
  tearDown(() async {
    auth.dispose();
    await repository.dispose();
  });

  test('espera al stream y responde a entrada y salida de sesión', () async {
    final delayedRepository = FakeAuthRepository(emitInitial: false);
    final delayedAuth = AuthProvider(repository: delayedRepository);
    expect(delayedAuth.checkingSession, isTrue);
    await flushEvents();
    expect(delayedAuth.checkingSession, isTrue);
    delayedRepository.emit(null);
    await flushEvents();
    expect(delayedAuth.checkingSession, isFalse);
    delayedAuth.dispose();
    await delayedRepository.dispose();
    await flushEvents();
    expect(auth.checkingSession, isFalse);
    expect(auth.isAuthenticated, isFalse);
    repository.emit(FakeFirebaseUser());
    await flushEvents();
    expect(auth.uid, 'test-uid');
    expect(auth.email, 'persona@example.test');
    await auth.signOut();
    await flushEvents();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.email, isNull);
  });

  test('bloquea envíos duplicados y recupera loading tras un error', () async {
    await flushEvents();
    final pending = Completer<void>();
    repository.signInAction = () => pending.future;
    final first = auth.signIn('a@example.test', 'password');
    expect(auth.loading, isTrue);
    expect(await auth.signIn('a@example.test', 'password'), isFalse);
    expect(repository.signInCalls, 1);
    pending.completeError(const AuthFailure('Revisa tu conexión a internet.'));
    expect(await first, isFalse);
    expect(auth.loading, isFalse);
    expect(auth.error, 'Revisa tu conexión a internet.');
    repository.signInAction = null;
    expect(await auth.signIn('a@example.test', 'password'), isTrue);
    await flushEvents();
    expect(auth.error, isNull);
    expect(auth.isAuthenticated, isTrue);
  });

  test(
    'Google cancelado libera loading sin error y espera la sesión Firebase',
    () async {
      await flushEvents();
      final pending = Completer<void>();
      repository.googleAction = () => pending.future;
      final result = auth.signInWithGoogle();
      expect(auth.loading, true);
      expect(await auth.signInWithGoogle(), false);
      pending.completeError(const AuthCancelled());
      expect(await result, false);
      expect(auth.loading, false);
      expect(auth.error, isNull);
      expect(auth.isAuthenticated, false);
      repository.googleAction = null;
      expect(await auth.signInWithGoogle(), true);
      await flushEvents();
      expect(auth.displayName, 'Nombre Google');
      expect(auth.isAuthenticated, true);
    },
  );
  test('logout fallido conserva sesión y muestra error', () async {
    await flushEvents();
    repository.emit(FakeFirebaseUser());
    await flushEvents();
    repository.signOutAction = () async =>
        throw const AuthFailure('No se pudo cerrar sesión.');
    expect(await auth.signOut(), isFalse);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.error, 'No se pudo cerrar sesión.');
    expect(auth.loading, isFalse);
  });

  test('error del stream permite reintentar la comprobación', () async {
    await flushEvents();
    repository.events.addError(const AuthFailure('Sin conexión.'));
    await flushEvents();
    expect(auth.sessionError, 'Sin conexión.');
    await auth.retrySession();
    await flushEvents();
    expect(auth.checkingSession, isFalse);
    expect(auth.sessionError, isNull);
  });

  test(
    'operación pendiente termina sin notificar un provider eliminado',
    () async {
      final localRepository = FakeAuthRepository();
      final localAuth = AuthProvider(repository: localRepository);
      final pending = Completer<void>();
      localRepository.signInAction = () => pending.future;
      final operation = localAuth.signIn('a@example.test', 'password');
      localAuth.dispose();
      pending.complete();
      expect(await operation, isFalse);
      await localRepository.dispose();
    },
  );

  test('fallo inesperado produce mensaje seguro y libera loading', () async {
    repository.signInAction = () async => throw StateError('detalle interno');
    expect(await auth.signIn('a@example.test', 'password'), isFalse);
    expect(auth.error, 'Ocurrió un problema inesperado. Inténtalo de nuevo.');
    expect(auth.loading, isFalse);
  });
}
