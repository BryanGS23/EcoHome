# Eliminación de usuarios

`deleteUserAccount` es una función callable en `us-central1`. Solo administradores activos pueden eliminar otras cuentas. No permite autoeliminación. Elimina el acceso de Authentication, el perfil y las alertas privadas. Conserva actividad, dispositivos, escenas y energía compartida. La persona podría registrarse de nuevo con una cuenta nueva; esto no es una prohibición permanente del correo.

Antes de eliminar Authentication se desactiva el perfil y se escribe una marca privada en `_user_deletions/{uid}`. Las reglas impiden que tokens anteriores reconstruyan el perfil. Si ocurre un fallo, un administrador puede reintentar la operación. La marca se conserva para proteger el acceso y la auditoría.

Preparación y despliegue desde `movil`:

```powershell
cd functions
npm ci
cd ..
firebase deploy --only functions:ecohome,firestore:rules --project ecohome-3c91d
```

Cloud Functions requiere los servicios correspondientes y un proyecto con facturación habilitada. Esta configuración no modifica automáticamente el plan de Firebase.

Estado al 2026-11-05: el despliegue en `ecohome-3c91d` está pendiente porque Firebase exige cambiar al plan Blaze. El servicio aún no está publicado. El botón no puede eliminar cuentas hasta completar ese paso. Las pruebas locales están aprobadas.

Pruebas locales sin borrar cuentas reales:

```powershell
firebase emulators:exec --only firestore --project demo-ecohome-rules --config firebase.rules-test.json "node --test rules-tests/firestore.test.cjs functions/test/delete_account.test.cjs"
```
