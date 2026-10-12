import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Installation-scoped reception only. No user token directory or push sender.
class PushService extends ChangeNotifier {
  final _messaging = FirebaseMessaging.instance;
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _token;
  // Debugger-only access for Firebase Console test delivery. Never render/log it.
  String? get debugToken => kDebugMode ? _token : null;
  String status = 'Activa las notificaciones push en este teléfono.';
  bool requesting = false, openNotifications = false;
  String? foregroundMessage;
  Future<void> start() async {
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        foregroundMessage =
            '${message.notification?.title ?? 'Push recibido'}\n${message.notification?.body ?? ''}';
        notifyListeners();
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        openNotifications = true;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _messaging.onTokenRefresh.listen(
        (token) {
          _token = token;
        },
        onError: (Object e) {
          status =
              'No se pudo renovar el registro push. Reintenta activar notificaciones.';
          notifyListeners();
        },
      ),
    );
    try {
      if (await _messaging.getInitialMessage() != null) {
        openNotifications = true;
        notifyListeners();
      }
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _register();
      }
    } catch (_) {
      status = 'Push no disponible. Puedes reintentar desde Notificaciones.';
      notifyListeners();
    }
  }

  Future<void> enable() async {
    if (requesting) return;
    requesting = true;
    notifyListeners();
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _register();
      } else {
        status =
            'Permiso no concedido. Puedes habilitarlo en Ajustes de Android → EcoHome → Notificaciones.';
      }
    } catch (_) {
      status =
          'No se pudo registrar push. Revisa Internet y Google Play Services.';
    } finally {
      requesting = false;
      notifyListeners();
    }
  }

  Future<void> _register() async {
    await _messaging.setAutoInitEnabled(true);
    _token = await _messaging.getToken();
    status = _token == null
        ? 'Registro push pendiente; reintenta.'
        : 'Push habilitado en este teléfono.';
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _token = null;
    super.dispose();
  }
}
