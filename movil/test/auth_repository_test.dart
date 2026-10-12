import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/repositories/auth_repository.dart';
import 'package:movil/services/auth_service.dart';

class _FakeService implements AuthService {
  String? code;
  Object? googleFailure;
  @override
  Future<void> signInWithGoogle() async {
    if (googleFailure != null) throw googleFailure!;
    if (code != null) throw FirebaseAuthException(code: code!);
  }

  String? receivedEmail;
  String? receivedPassword;
  @override
  User? get currentUser => null;
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  Future<void> signIn(String email, String password) async {
    receivedEmail = email;
    receivedPassword = password;
    if (code != null) throw FirebaseAuthException(code: code!);
  }

  @override
  Future<void> register(String email, String password) =>
      signIn(email, password);
  @override
  Future<void> resetPassword(String email) => signIn(email, '');
  @override
  Future<void> signOut() async {
    if (code != null) throw FirebaseAuthException(code: code!);
  }
}

void main() {
  test('recorta correo pero preserva la contraseña', () async {
    final service = _FakeService();
    final repository = AuthRepository(service: service);
    await repository.signIn(' a@example.test ', ' password ');
    expect(service.receivedEmail, 'a@example.test');
    expect(service.receivedPassword, ' password ');
  });

  test(
    'credenciales inexistentes e incorrectas tienen el mismo mensaje',
    () async {
      final service = _FakeService();
      final repository = AuthRepository(service: service);
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
      ]) {
        service.code = code;
        await expectLater(
          repository.signIn('a@example.test', 'password'),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.message,
              'mensaje',
              'El correo o la contraseña no son correctos.',
            ),
          ),
        );
      }
    },
  );

  test('traduce errores comunes sin exponer códigos Firebase', () async {
    final service = _FakeService();
    final repository = AuthRepository(service: service);
    for (final code in [
      'invalid-email',
      'weak-password',
      'email-already-in-use',
      'too-many-requests',
      'network-request-failed',
      'operation-not-allowed',
      'user-disabled',
      'unknown',
    ]) {
      service.code = code;
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        repository.register('a@example.test', 'password'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message.contains(code),
            'no muestra el código',
            isFalse,
          ),
        ),
      );
    }
  });

  test(
    'Google traduce cancelación y conflicto sin exponer credenciales',
    () async {
      final service = _FakeService();
      final repository = AuthRepository(service: service);
      service.googleFailure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthCancelled>()),
      );
      service.googleFailure = null;
      service.code = 'account-exists-with-different-credential';
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'método original',
            contains('método original'),
          ),
        ),
      );
    },
  );
  test(
    'recuperación no revela cuenta inexistente pero conserva error de red',
    () async {
      final service = _FakeService()..code = 'user-not-found';
      final repository = AuthRepository(service: service);
      await repository.resetPassword('a@example.test');
      service.code = 'network-request-failed';
      await expectLater(
        repository.resetPassword('a@example.test'),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
}
