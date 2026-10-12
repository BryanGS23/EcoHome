import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository() {
    _listenToSession();
  }

  final AuthRepository _repository;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;
  bool _checkingSession = true;
  bool _loading = false;
  String? _uid;
  String? _email;
  String? _displayName;
  String? _error;
  String? _sessionError;

  bool get checkingSession => _checkingSession;
  bool get loading => _loading;
  bool get isAuthenticated => _uid != null;
  String? get uid => _uid;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get error => _error;
  String? get sessionError => _sessionError;

  void _listenToSession() {
    _subscription = _repository.authStateChanges.listen(
      (user) {
        if (_disposed) return;
        _uid = user?.uid;
        _email = user?.email;
        _displayName = user?.displayName;
        _checkingSession = false;
        _sessionError = null;
        _error = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed) return;
        _checkingSession = false;
        _sessionError = _messageFor(error, stack);
        notifyListeners();
      },
    );
  }

  Future<void> retrySession() async {
    if (_checkingSession || _disposed) return;
    _checkingSession = true;
    _sessionError = null;
    notifyListeners();
    await _subscription?.cancel();
    if (!_disposed) _listenToSession();
  }

  void clearError() {
    if (_error == null || _disposed) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _repository.signIn(email, password));
  Future<bool> register(String email, String password) =>
      _run(() => _repository.register(email, password));
  Future<bool> resetPassword(String email) =>
      _run(() => _repository.resetPassword(email));
  Future<bool> signOut() => _run(_repository.signOut);
  Future<bool> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<bool> _run(Future<void> Function() operation) async {
    if (_loading || _disposed) return false;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      return !_disposed;
    } on AuthCancelled {
      return false;
    } catch (error, stack) {
      if (!_disposed) _error = _messageFor(error, stack);
      return false;
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  String _messageFor(Object error, StackTrace stack) {
    if (error is AuthFailure) return error.message;
    // Diagnóstico sin registrar credenciales ni mensajes del SDK con datos personales.
    developer.log(
      'Fallo inesperado de autenticación (${error.runtimeType}).',
      name: 'EcoHome.Auth',
      stackTrace: stack,
      level: 1000,
    );
    return 'Ocurrió un problema inesperado. Inténtalo de nuevo.';
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
