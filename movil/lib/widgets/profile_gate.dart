import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/user_repository.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.auth,
    this.repository,
    required this.builder,
  });
  final AuthProvider auth;
  final UserRepository? repository;
  final Widget Function(UserProvider) builder;
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final UserProvider _user;
  @override
  void initState() {
    super.initState();
    _user = UserProvider(
      uid: widget.auth.uid!,
      email: widget.auth.email ?? '',
      displayName: widget.auth.displayName,
      repository: widget.repository ?? UserRepository(),
    )..load();
  }

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_user, widget.auth]),
    builder: (context, _) {
      if (_user.status == ProfileStatus.ready) return widget.builder(_user);
      final loading = _user.status == ProfileStatus.loading;
      final inactive = _user.status == ProfileStatus.inactive;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    loading
                        ? 'Verificando perfil…'
                        : inactive
                        ? 'Cuenta desactivada'
                        : _user.status == ProfileStatus.missing
                        ? 'No existe tu perfil. Reintenta para crearlo.'
                        : _user.error!,
                    textAlign: TextAlign.center,
                  ),
                  if (inactive)
                    const Text(
                      'Contacta con el administrador para recuperar el acceso.',
                    ),
                  if (!loading && !inactive)
                    TextButton(
                      onPressed: _user.load,
                      child: const Text('Reintentar'),
                    ),
                  if (widget.auth.error != null) Text(widget.auth.error!),
                  TextButton(
                    onPressed: widget.auth.loading ? null : widget.auth.signOut,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
