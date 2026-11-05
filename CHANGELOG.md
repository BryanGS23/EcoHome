# Registro de cambios

## 1.3.0+6 — 2026-11-05

- Agrega eliminación de usuarios desde Administración con confirmación y bloqueo de autoeliminación.
- La función de servidor verifica que quien solicita la operación sea un administrador activo; elimina Authentication, perfil y alertas propias.
- Conserva los datos compartidos y registra la eliminación en la actividad histórica.
- Bloquea la recreación del perfil con tokens anteriores y permite completar eliminaciones interrumpidas.
- Requiere desplegar `deleteUserAccount` en Cloud Functions y actualizar las reglas Firestore.
- Activación pendiente: Firebase exige plan Blaze para publicar el servicio; no se modificó el plan del proyecto.

## 1.2.0+5 — 2026-11-05

- Cada pulsación de «Simular 1 hora» agrega otra hora al consumo acumulado con el estado actual de los dispositivos.
- Los dispositivos apagados o sin conexión aportan 0 Wh. Se conservan los registros anteriores.
- Los reintentos de una operación parcial durante la misma sesión completan esa hora sin duplicar registros ya guardados.
- Actualiza las reglas Firestore para admitir múltiples simulaciones por día y conserva compatibilidad con muestras de versiones anteriores.

## 1.1.1+4 — 2026-11-04

- Marca las alertas como leídas al abrir Notificaciones y mientras la sección permanece visible, tanto en web como en Android.
- Actualiza el contador solo al confirmar el guardado; permite reintentar si falla la conexión.
- Muestra el nombre de la cuenta en Mi actividad y en Actividad global para creaciones de dispositivos, escenas y ejecuciones, incluidos los registros existentes.
- Los nombres corresponden al perfil actual; las cuentas no disponibles muestran «Usuario no disponible».

## 1.1.0+3 — 2026-11-04

- Agrega compatibilidad con navegador y configuración Firebase para web.
- Adapta el inicio de sesión con Google a una ventana emergente en web.
- Reserva el registro de notificaciones push para Android y conserva las notificaciones dentro de la app.
- Agrega `movil/ABRIR_EN_NAVEGADOR.bat` e instrucciones de pruebas web.
- Actualiza el nombre y la descripción de la aplicación web a EcoHome.

El número de compilación 3 continúa después del APK existente 1.0.1-2. La versión 1.1.0 identifica la incorporación de la plataforma web.
