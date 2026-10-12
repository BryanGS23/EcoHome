import 'package:flutter_test/flutter_test.dart';
import 'package:movil/validation/auth_validators.dart';

void main() {
  test('valida correo y permite espacios exteriores', () {
    for (final value in [
      null,
      '',
      'correo',
      'a@',
      'a b@example.test',
      'a@@b.test',
    ]) {
      expect(AuthValidators.email(value), isNotNull);
    }
    expect(AuthValidators.email(' persona+hogar@example.test '), isNull);
  });

  test('registro exige seis caracteres y confirmación exacta', () {
    for (final value in [null, '', '12345', '      ']) {
      expect(AuthValidators.newPassword(value), isNotNull);
    }
    expect(AuthValidators.newPassword('clave segura'), isNull);
    expect(
      AuthValidators.confirmPassword('clave segura', 'clave segura'),
      isNull,
    );
    expect(
      AuthValidators.confirmPassword('clave segura ', 'clave segura'),
      isNotNull,
    );
    expect(AuthValidators.confirmPassword('', ''), isNotNull);
    expect(AuthValidators.password(''), isNotNull);
    // Login no impone nuevas reglas a una contraseña existente.
    expect(AuthValidators.password('12345'), isNull);
  });
}
