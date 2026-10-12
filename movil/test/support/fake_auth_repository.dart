import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:movil/repositories/auth_repository.dart';

/// Solo datos en memoria; nunca crea cuentas ni contacta con Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser, this.emitInitial = true});
  @override
  User? currentUser;
  bool emitInitial;
  final events = StreamController<User?>.broadcast();
  Future<void> Function()? signInAction;
  Future<void> Function()? signOutAction;
  Future<void> Function()? googleAction;
  @override
  Future<void> signInWithGoogle() async {
    if (googleAction != null) {
      await googleAction!();
      return;
    }
    emit(FakeFirebaseUser(displayName: 'Nombre Google'));
  }

  int signInCalls = 0;
  int registerCalls = 0;
  int resetCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<User?> get authStateChanges async* {
    if (emitInitial) yield currentUser;
    yield* events.stream;
  }

  void emit(User? user) {
    currentUser = user;
    events.add(user);
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (signInAction != null) {
      await signInAction!();
      return;
    }
    emit(FakeFirebaseUser(email: email));
  }

  @override
  Future<void> register(String email, String password) async {
    registerCalls++;
    emit(FakeFirebaseUser(email: email));
  }

  @override
  Future<void> resetPassword(String email) async => resetCalls++;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutAction != null) {
      await signOutAction!();
      return;
    }
    emit(null);
  }

  Future<void> dispose() => events.close();
}

class FakeFirebaseUser implements User {
  FakeFirebaseUser({
    this.displayName,
    this.uid = 'test-uid',
    this.email = 'persona@example.test',
  });
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
