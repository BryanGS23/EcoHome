import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/app_user.dart';
import '../widgets/eco_bottom_navigation.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.user,
    required this.onNavigate,
  });
  final AuthProvider auth;
  final UserProvider user;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([auth, user]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 4,
        onTap: onNavigate,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 64,
              color: Color(0xFF28B86B),
            ),
            const SizedBox(height: 16),
            Text(
              auth.email ?? 'Sesión iniciada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Text('Nombre: ${user.profile?.name ?? ""}'),
            Text('Rol: ${user.profile?.role.name ?? ""}'),
            Text(
              'Estado: ${user.profile?.active == true ? "Activo" : "Inactivo"}',
            ),
            OutlinedButton(
              onPressed: user.saving ? null : () => _editName(context),
              child: Text(user.saving ? 'Guardando…' : 'Editar nombre'),
            ),
            if (user.editError != null) Text(user.editError!),
            OutlinedButton.icon(
              onPressed: () => onNavigate(5),
              icon: const Icon(Icons.history),
              label: const Text('Mi actividad'),
            ),
            if (user.isAdmin) ...[
              const Text('Administración'),
              OutlinedButton.icon(
                onPressed: () => onNavigate(6),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text(
                  'Usuarios · Áreas · Dispositivos · Escenas · Actividad',
                ),
              ),
            ],
            if (auth.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  auth.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: auth.loading ? null : () => auth.signOut(),
              icon: auth.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(auth.loading ? 'Cerrando sesión…' : 'Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _editName(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initialName: user.profile!.name),
    );
    if (name != null && context.mounted) await user.updateName(name);
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initialName});
  final String initialName;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar nombre'),
    content: Form(
      key: _form,
      child: TextFormField(
        key: const ValueKey('profile-name'),
        controller: _name,
        autofocus: true,
        maxLength: 80,
        validator: AppUser.validateName,
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
