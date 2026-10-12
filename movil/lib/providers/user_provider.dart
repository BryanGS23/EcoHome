import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';

enum ProfileStatus { loading, missing, ready, inactive, error }

class UserProvider extends ChangeNotifier {
  UserProvider({
    required this.uid,
    required this.email,
    required this.repository,
    this.displayName,
  });
  final String uid, email;
  final String? displayName;
  final UserRepository repository;
  StreamSubscription<AppUser?>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  ProfileStatus status = ProfileStatus.loading;
  AppUser? profile;
  String? error;
  String? editError;
  bool saving = false;
  bool get isAdmin =>
      status == ProfileStatus.ready &&
      profile?.active == true &&
      profile?.role == UserRole.admin;

  Future<void> load() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    status = ProfileStatus.loading;
    profile = null;
    error = null;
    notifyListeners();
    try {
      await repository
          .ensureProfile(uid, email, displayName: displayName)
          .timeout(const Duration(seconds: 20));
      if (_disposed || generation != _generation) return;
      _subscription = repository
          .watchProfile(uid)
          .listen(
            (value) {
              if (_disposed || generation != _generation) return;
              profile = value;
              status = value == null
                  ? ProfileStatus.missing
                  : value.active
                  ? ProfileStatus.ready
                  : ProfileStatus.inactive;
              error = null;
              notifyListeners();
            },
            onError: (Object failure) {
              if (!_disposed && generation == _generation) _fail();
            },
          );
    } catch (_) {
      if (!_disposed && generation == _generation) _fail();
    }
  }

  void _fail() {
    profile = null;
    status = ProfileStatus.error;
    error =
        'No se pudo verificar tu perfil en Firestore. Comprueba tu conexión y reintenta.';
    notifyListeners();
  }

  Future<bool> updateName(String name) async {
    if (_disposed || saving || status != ProfileStatus.ready) return false;
    saving = true;
    editError = null;
    notifyListeners();
    try {
      await repository.updateName(uid, name);
      return !_disposed;
    } catch (_) {
      if (!_disposed) {
        editError =
            'No se pudo guardar el nombre. Revisa tu conexión e inténtalo de nuevo.';
      }
      return false;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _subscription?.cancel();
    super.dispose();
  }
}
