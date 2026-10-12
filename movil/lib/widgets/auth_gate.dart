import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.signedInBuilder,
  });
  final AuthProvider auth;
  final WidgetBuilder signedInBuilder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (context, _) {
      if (auth.checkingSession || auth.sessionError != null) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 52,
                      color: Color(0xFF28B86B),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'EcoHome',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (auth.checkingSession) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Comprobando sesión…'),
                    ] else ...[
                      Text(auth.sessionError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: auth.retrySession,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (!auth.isAuthenticated) return AuthScreen(auth: auth);
      return KeyedSubtree(
        key: ValueKey(auth.uid),
        child: signedInBuilder(context),
      );
    },
  );
}
