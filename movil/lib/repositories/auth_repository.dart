import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';

class AuthCancelled implements Exception {
  const AuthCancelled();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  factory AuthFailure.fromFirebase(FirebaseAuthException error) {
    return AuthFailure(switch (error.code) {
      'invalid-email' => 'Escribe un correo electrónico válido.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'El correo o la contraseña no son correctos.',
      'email-already-in-use' =>
        'No se pudo crear la cuenta. Intenta iniciar sesión o recuperar tu contraseña.',
      'weak-password' || 'password-does-not-meet-requirements' =>
        'La contraseña no cumple los requisitos de seguridad. Usa una contraseña más segura.',
      'too-many-requests' =>
        'Se realizaron demasiados intentos. Espera un momento y vuelve a intentarlo.',
      'network-request-failed' =>
        'No pudimos conectarnos. Revisa tu conexión a internet.',
      'user-disabled' =>
        'No se puede acceder a esta cuenta. Contacta con soporte.',
      'operation-not-allowed' =>
        'El acceso con correo y contraseña no está disponible. Contacta con soporte.',
      'requires-recent-login' || 'user-token-expired' || 'invalid-user-token' =>
        'Tu sesión necesita renovarse. Vuelve a iniciar sesión.',
      _ => 'No pudimos completar la operación. Inténtalo de nuevo.',
    });
  }
}

class AuthRepository {
  AuthRepository({AuthService? service}) : _service = service ?? AuthService();
  final AuthService _service;

  User? get currentUser => _service.currentUser;
  Stream<User?> get authStateChanges =>
      _service.authStateChanges.handleError((Object error) {
        if (error is FirebaseAuthException) {
          throw AuthFailure.fromFirebase(error);
        }
        throw error;
      });

  Future<void> signIn(String email, String password) =>
      _translate(() => _service.signIn(email.trim(), password));

  Future<void> register(String email, String password) =>
      _translate(() => _service.register(email.trim(), password));

  Future<void> resetPassword(String email) async {
    try {
      await _service.resetPassword(email.trim());
    } on FirebaseAuthException catch (error) {
      // Misma confirmación si Firebase informa de un correo sin cuenta.
      if (error.code == 'user-not-found') return;
      throw AuthFailure.fromFirebase(error);
    }
  }

  Future<void> signOut() => _translate(_service.signOut);

  Future<void> signInWithGoogle() async {
    try {
      await _service.signInWithGoogle();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelled();
      }
      throw AuthFailure(switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google no está disponible con esta configuración. Contacta con el responsable de EcoHome.',
        GoogleSignInExceptionCode.interrupted ||
        GoogleSignInExceptionCode.uiUnavailable =>
          'Se interrumpió el acceso con Google. Vuelve a intentarlo.',
        _ =>
          'No pudimos acceder con Google. Revisa tu conexión y vuelve a intentarlo.',
      });
    } on FirebaseAuthException catch (error) {
      throw switch (error.code) {
        'account-exists-with-different-credential' ||
        'credential-already-in-use' ||
        'email-already-in-use' => const AuthFailure(
          'Este correo ya utiliza otro método de acceso. Inicia sesión con tu método original; la vinculación de Google requiere verificar esa cuenta y no se realiza automáticamente desde EcoHome.',
        ),
        'operation-not-allowed' => const AuthFailure(
          'El acceso con Google no está habilitado. Contacta con el responsable de EcoHome.',
        ),
        'invalid-credential' => const AuthFailure(
          'No se pudo validar la credencial de Google. Selecciona de nuevo tu cuenta.',
        ),
        _ => AuthFailure.fromFirebase(error),
      };
    } catch (_) {
      throw const AuthFailure(
        'No pudimos acceder con Google. Revisa la conexión y los servicios de Google del teléfono.',
      );
    }
  }

  Future<void> _translate(Future<void> Function() operation) async {
    try {
      await operation();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromFirebase(error);
    }
  }
}
