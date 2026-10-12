import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../validation/auth_validators.dart';

enum _AuthPage { login, register, recovery }

/// Los tres formularios comparten diseño; no apilan rutas encima del Auth Gate.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});
  final AuthProvider auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _AuthPage _page = _AuthPage.login;
  bool _obscure = true;
  String? _success;

  void _navigate(_AuthPage page) {
    if (widget.auth.loading) return;
    FocusScope.of(context).unfocus();
    _form.currentState?.reset();
    widget.auth.clearError();
    setState(() {
      _page = page;
      _success = null;
      _obscure = true;
      _password.clear();
      _confirmation.clear();
    });
  }

  Future<void> _submit() async {
    if (widget.auth.loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _success = null);
    final page = _page;
    final success = switch (page) {
      _AuthPage.login => await widget.auth.signIn(_email.text, _password.text),
      _AuthPage.register => await widget.auth.register(
        _email.text,
        _password.text,
      ),
      _AuthPage.recovery => await widget.auth.resetPassword(_email.text),
    };
    if (!mounted || !success) return;
    _password.clear();
    _confirmation.clear();
    if (page == _AuthPage.recovery) {
      setState(() {
        _success =
            'Si existe una cuenta con ese correo, recibirás un enlace para restablecer tu contraseña. Revisa también spam.';
      });
    }
    // Login y registro cambian de pantalla exclusivamente mediante authStateChanges.
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final login = _page == _AuthPage.login;
    final register = _page == _AuthPage.register;
    final recovery = _page == _AuthPage.recovery;
    final title = login
        ? 'Bienvenido a casa'
        : register
        ? 'Crear cuenta'
        : 'Recuperar contraseña';
    final button = login
        ? 'Iniciar sesión'
        : register
        ? 'Registrarme'
        : 'Enviar enlace';
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final loading = widget.auth.loading;
        return PopScope(
          canPop: login && !loading,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !loading && !login) _navigate(_AuthPage.login);
          },
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.eco_outlined,
                              size: 52,
                              color: Color(0xFF28B86B),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'EcoHome',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              recovery
                                  ? 'Te ayudamos a volver a entrar a tu hogar.'
                                  : 'Tu hogar conectado, en un solo lugar.',
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              key: const ValueKey('auth-email'),
                              controller: _email,
                              enabled: !loading,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: recovery
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              validator: AuthValidators.email,
                              onFieldSubmitted: recovery
                                  ? (_) => _submit()
                                  : null,
                            ),
                            if (!recovery) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const ValueKey('auth-password'),
                                controller: _password,
                                enabled: !loading,
                                obscureText: _obscure,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: [
                                  register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                textInputAction: register
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  helperText: register
                                      ? 'Al menos 6 caracteres'
                                      : null,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    onPressed: loading
                                        ? null
                                        : () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: register
                                    ? AuthValidators.newPassword
                                    : AuthValidators.password,
                                onFieldSubmitted: login
                                    ? (_) => _submit()
                                    : null,
                              ),
                            ],
                            if (register) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const ValueKey('auth-confirmation'),
                                controller: _confirmation,
                                enabled: !loading,
                                obscureText: _obscure,
                                enableSuggestions: false,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.done,
                                validator: (value) =>
                                    AuthValidators.confirmPassword(
                                      value,
                                      _password.text,
                                    ),
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ],
                            if (widget.auth.error != null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  widget.auth.error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            if (_success != null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _success!,
                                  style: const TextStyle(
                                    color: Color(0xFF16703E),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: loading ? null : _submit,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          semanticsLabel: 'Procesando',
                                        ),
                                      )
                                    : Text(button),
                              ),
                            ),
                            if (login) ...[
                              const SizedBox(height: 12),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text('o'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: loading
                                    ? null
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        widget.auth.signInWithGoogle();
                                      },
                                icon: const Text(
                                  'G',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                label: const Text('Continuar con Google'),
                              ),
                              TextButton(
                                onPressed: loading
                                    ? null
                                    : () => _navigate(_AuthPage.recovery),
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                              OutlinedButton(
                                onPressed: loading
                                    ? null
                                    : () => _navigate(_AuthPage.register),
                                child: const Text('Crear cuenta'),
                              ),
                            ] else
                              TextButton(
                                onPressed: loading
                                    ? null
                                    : () => _navigate(_AuthPage.login),
                                child: const Text('Volver a iniciar sesión'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
