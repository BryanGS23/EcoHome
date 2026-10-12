import 'screens/admin_screen.dart';
import 'providers/energy_provider.dart';
import 'providers/activity_provider.dart';
import 'repositories/energy_repository.dart';
import 'repositories/activity_repository.dart';
import 'screens/energy_screen.dart';
import 'screens/activity_screen.dart';
import 'providers/scene_provider.dart';
import 'repositories/scene_repository.dart';
import 'providers/area_provider.dart';
import 'providers/device_provider.dart';
import 'repositories/area_repository.dart';
import 'repositories/device_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/user_repository.dart';
import 'widgets/profile_gate.dart';
import 'screens/device_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scenes_screen.dart';
import 'providers/notification_provider.dart';
import 'repositories/notification_repository.dart';
import 'screens/notifications_screen.dart';
import 'services/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'widgets/auth_gate.dart';

@pragma('vm:entry-point')
Future<void> onBackgroundPush(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(onBackgroundPush);
  final push = PushService();
  unawaited(push.start());
  runApp(EcoHomeApp(push: push));
}

class EcoHomeApp extends StatefulWidget {
  const EcoHomeApp({
    super.key,
    this.notificationRepository,
    this.push,
    this.authProvider,
    this.userRepository,
    this.areaRepository,
    this.deviceRepository,
    this.sceneRepository,
    this.energyRepository,
    this.activityRepository,
    this.createNotifications,
  });

  final NotificationRepository? notificationRepository;
  final PushService? push;
  final AuthProvider? authProvider;
  final UserRepository? userRepository;
  final AreaRepository? areaRepository;
  final DeviceRepository? deviceRepository;
  final SceneRepository? sceneRepository;
  final EnergyRepository? energyRepository;
  final ActivityRepository? activityRepository;
  final NotificationProvider Function(String uid)? createNotifications;

  @override
  State<EcoHomeApp> createState() => _EcoHomeAppState();
}

class _EcoHomeAppState extends State<EcoHomeApp> {
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.authProvider ?? AuthProvider();
  }

  @override
  void dispose() {
    if (widget.authProvider == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoHome',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28B86B)),
        scaffoldBackgroundColor: const Color(0xFFF8F9F8),
        fontFamily: 'Arial',
      ),
      home: AuthGate(
        auth: _auth,
        signedInBuilder: (_) => ProfileGate(
          auth: _auth,
          repository: widget.userRepository,
          builder: (user) => _AuthenticatedHome(
            auth: _auth,
            user: user,
            areaRepository: widget.areaRepository,
            deviceRepository: widget.deviceRepository,
            sceneRepository: widget.sceneRepository,
            energyRepository: widget.energyRepository,
            activityRepository: widget.activityRepository,
            notificationRepository: widget.notificationRepository,
            push: widget.push,
            createNotifications: widget.createNotifications,
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({
    required this.auth,
    required this.user,
    this.areaRepository,
    this.deviceRepository,
    this.sceneRepository,
    this.energyRepository,
    this.activityRepository,
    this.notificationRepository,
    this.push,
    this.createNotifications,
  });
  final AuthProvider auth;
  final UserProvider user;
  final AreaRepository? areaRepository;
  final DeviceRepository? deviceRepository;
  final SceneRepository? sceneRepository;
  final EnergyRepository? energyRepository;
  final ActivityRepository? activityRepository;
  final NotificationRepository? notificationRepository;
  final PushService? push;
  final NotificationProvider Function(String uid)? createNotifications;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late final NotificationProvider _notifications;
  late final AreaProvider _areas;
  late final DeviceProvider _devices;
  late final SceneProvider _scenes;
  late final EnergyProvider _energy;
  late final ActivityProvider _activity;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _areas = AreaProvider(
      repository: widget.areaRepository ?? AreaRepository(),
    );
    _devices = DeviceProvider(
      repository: widget.deviceRepository ?? DeviceRepository(),
    );
    _scenes = SceneProvider(
      repository: widget.sceneRepository ?? SceneRepository(),
    );
    _energy = EnergyProvider(
      repository: widget.energyRepository ?? EnergyRepository(),
    );
    _activity = ActivityProvider(
      repository: widget.activityRepository ?? ActivityRepository(),
      uid: widget.auth.uid!,
    );
    _notifications =
        widget.createNotifications?.call(widget.auth.uid!) ??
        NotificationProvider(
          uid: widget.auth.uid!,
          repository: widget.notificationRepository ?? NotificationRepository(),
        );
    widget.push?.addListener(_onPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPush());
  }

  @override
  void dispose() {
    _areas.dispose();
    _devices.dispose();
    _scenes.dispose();
    _energy.dispose();
    _activity.dispose();
    widget.push?.removeListener(_onPush);
    _notifications.dispose();
    super.dispose();
  }

  void _onPush() {
    if (!mounted || widget.user.profile?.active != true) return;
    final push = widget.push;
    if (push == null) return;
    if (push.openNotifications) {
      push.openNotifications = false;
      _navigateTo(7);
    }
    final message = push.foregroundMessage;
    if (message != null) {
      push.foregroundMessage = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Push recibido: $message'),
          action: SnackBarAction(label: 'Ver', onPressed: () => _navigateTo(7)),
        ),
      );
    }
  }

  void _navigateTo(int index) {
    if (!mounted) return;
    widget.auth.clearError();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      _notifications,
      _devices,
      _areas,
      _energy,
      widget.user,
    ]),
    builder: (context, _) {
      return IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            notifications: _notifications,
            devices: _devices,
            areas: _areas,
            scenes: _scenes,
            energy: _energy,
            onNavigate: _navigateTo,
          ),
          DeviceScreen(
            areas: _areas,
            devices: _devices,
            onNavigate: _navigateTo,
          ),
          ScenesScreen(scenes: _scenes, onNavigate: _navigateTo),
          EnergyScreen(
            energy: _energy,
            devices: _devices,
            areas: _areas,
            onNavigate: _navigateTo,
          ),
          ProfileScreen(
            auth: widget.auth,
            user: widget.user,
            onNavigate: _navigateTo,
          ),
          ActivityScreen(activity: _activity, onNavigate: _navigateTo),
          if (_currentIndex == 6)
            AdminScreen(user: widget.user, onBack: () => _navigateTo(4))
          else
            const SizedBox.shrink(),
          NotificationsScreen(
            notifications: _notifications,
            push: widget.push,
            onBack: () => _navigateTo(0),
          ),
        ],
      );
    },
  );
}
