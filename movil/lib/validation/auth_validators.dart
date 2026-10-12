class AuthValidators {
  const AuthValidators._();

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Escribe un correo electrónico válido.';
    }
    return null;
  }

  static String? password(String? value) =>
      value == null || value.isEmpty ? 'Escribe tu contraseña.' : null;

  static String? newPassword(String? value) {
    if (value == null || value.trim().isEmpty || value.length < 6) {
      return 'Usa una contraseña de al menos 6 caracteres.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) =>
      value == null || value.isEmpty || value != password
      ? 'Las contraseñas deben coincidir.'
      : null;
}
