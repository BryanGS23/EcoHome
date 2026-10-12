# EcoHome

**Estado vigente: Fase 10. EcoHome v2 ya no requiere Node/WebSocket para su funcionamiento.**
Las instrucciones de fases anteriores se conservan como historial; véase Fase 10 al final.

EcoHome es una aplicación Flutter de casa inteligente simulada. El prototipo
muestra un resumen del hogar, dispositivos por área y escenas, con datos de
demostración. Actualmente no controla hardware real; las escenas aplican
configuraciones simuladas a los dispositivos de Firestore.

Cloud Firestore sincroniza perfiles, áreas, dispositivos, escenas, energía simulada, actividad y alertas.
FCM recibe push Android; server/ se conserva únicamente como referencia histórica.

## Ejecutar el servidor del prototipo histórico (opcional; no utilizado por EcoHome v2)

Con Node.js y npm instalados, desde la raíz del proyecto:

```sh
cd server
npm ci
npm start
```

`npm ci` instala las dependencias del lockfile; solo es necesario al preparar
el entorno o cuando cambien las dependencias. El servidor utiliza el puerto
`8080`. Mantén esta terminal abierta mientras utilizas la aplicación.

## Ejecutar Flutter

Se necesita Flutter con Dart compatible con `^3.12.2`. Para validar Firebase y
el comportamiento nativo se prefiere un teléfono Android físico con depuración
USB habilitada. En otra terminal, desde la raíz del proyecto:

```sh
flutter pub get
flutter devices
flutter run
```

La URL predeterminada es `ws://10.0.2.2:8080`, para acceder al servidor de la
computadora desde el emulador Android.

Para un dispositivo físico, conecta ambos equipos a la misma red y sustituye
la dirección del ejemplo por la IP local de la computadora que ejecuta Node:

```sh
flutter run --dart-define=WEBSOCKET_URL=ws://192.168.1.100:8080
```

El puerto `8080` debe ser accesible desde el dispositivo. La URL se configura al
ejecutar o compilar Flutter; no se cambia desde la interfaz.

## Configuración base de Firebase

La aplicación Android está vinculada al proyecto Firebase `ecohome-3c91d`, con
package `com.ecohome.app` y nombre visible `EcoHome`. Utiliza `firebase_core`
`4.15.0`. FlutterFire CLI generó `lib/firebase_options.dart`,
`android/app/google-services.json` y `firebase.json` para Android.

Al arrancar, Flutter inicializa su binding, espera a `Firebase.initializeApp`
con `DefaultFirebaseOptions.currentPlatform` e inicia EcoHome. Perfiles, áreas y
dispositivos usan Firestore; las funciones antiguas pendientes conservan WebSocket.

Solo Android tiene opciones Firebase configuradas. El arranque en Web, Windows,
iOS, macOS y Linux no está habilitado por esta configuración.

## Autenticación

EcoHome utiliza `firebase_auth: 6.7.0` con correo y contraseña. El proveedor
Email/Password debe estar habilitado en Firebase Authentication del proyecto
`ecohome-3c91d`. No se utiliza Email Link.

La UI llama a `AuthProvider` (ChangeNotifier), que utiliza `AuthRepository` y
`AuthService`. Las pantallas no llaman directamente a Firebase. El Auth Gate
espera el primer evento de `authStateChanges`: sin sesión muestra Login, con
acceso a Registro y Recuperación; con sesión verifica el perfil antes de mostrar EcoHome. Firebase conserva
la sesión en Android, sin almacenamiento manual de contraseñas o tokens.

Registro solicita correo, contraseña y confirmación; al crear la cuenta Firebase
inicia la sesión. Recuperación envía el correo oficial y muestra una confirmación
genérica para no revelar si la cuenta existe. Perfil muestra nombre, correo,
rol y estado; permite editar el nombre y cerrar sesión. El stream devuelve la UI a Login.

`EcoHomeState` se crea al entrar a EcoHome y se elimina al salir, cerrando su
servicio WebSocket. Firebase Auth controla el acceso en esta aplicación, pero el
servidor Node sigue siendo el prototipo compartido: su protocolo no autentica
usuarios ni separa datos por cuenta.

### Validación

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Dentro de `server/`, ejecutar `node --test`. Las pruebas de Authentication usan
dobles en memoria: no requieren conexión ni crean cuentas reales.

Para la prueba real, inicia Node, conecta el teléfono por USB, autoriza depuración
y comprueba su ID con `flutter devices`. Con teléfono y PC en la misma red:

```sh
flutter run -d <ID_TELEFONO> --dart-define=WEBSOCKET_URL=ws://<IP_LOCAL_PC>:8080
```

Sustituye ambos marcadores por los valores de tu entorno. Prueba: abrir sin sesión,
registrarte con un correo tuyo, entrar a EcoHome, cerrar y reabrir la app para
comprobar persistencia, cerrar sesión desde Perfil, volver a iniciar sesión y
recuperar la contraseña. Comprueba también dispositivos y escenas con Node activo.

El emulador no es obligatorio: el cierre previo `LOW_MEMORY` fue una limitación
del entorno. Chrome es auxiliar para UI compatible; no se ha configurado Firebase
Web y este arranque de producción requiere Android.

## Evolución hacia EcoHome v2

El proyecto está en proceso de preparación y migración gradual hacia EcoHome v2.
Authentication y los perfiles persistentes con roles están implementados.
Cloud Firestore almacena `/users/{uid}`, `/areas/{areaId}` y `/devices/{deviceId}`.
WebSocket conserva las funciones antiguas pendientes. FCM y el panel administrativo siguen
fuera del alcance actual.

## Perfiles y roles — Fase 5

`cloud_firestore: 6.10.0` usa la base `(default)` de `ecohome-3c91d`, región
`northamerica-south1`. Solo Android está configurado para Firebase.

Flujo: Auth Gate → Profile Gate → UserProvider → UserRepository → FirestoreService.
El documento contiene exactamente `uid`, `name`, `email`, `role`, `active`,
`createdAt` y `updatedAt`. Las fechas son timestamps del servidor; AppUser las
representa como DateTime. Los roles válidos son `user` y `admin`.

Al entrar con una sesión autenticada, una transacción crea el documento únicamente
si falta. Esto sirve tanto para registros nuevos como para cuentas de la Fase 4.
Utiliza UID y correo de Authentication, nombre derivado del correo, `role: user`
y `active: true`. Un documento existente no se sobrescribe, incluso si es admin
o está inactivo. El registro conserva sus campos de correo y contraseña; el nombre
se puede corregir después desde Perfil.

El acceso espera un perfil confirmado por Firestore; un error, perfil inválido o
documento ausente no otorga acceso por defecto. La UI permite reintentar o cerrar
sesión. Un perfil `active: false` muestra Cuenta desactivada y desmonta el hogar,
liberando su conexión WebSocket; la cuenta Authentication permanece.

La escucha refleja cambios del servidor en rol y estado. La comprobación inicial
requiere red. Durante una desconexión no se pueden conocer cambios remotos hasta
recuperar comunicación. Este bloqueo pertenece al cliente EcoHome: el servidor
Node conserva su protocolo original, sin autorización por usuario.

`firestore.rules` permite solo lectura individual del perfil propio, creación
propia como user activo y modificación del nombre con updatedAt del servidor.
Prohíbe listados, borrados, campos extra y cambios de identidad, correo, rol,
estado o createdAt. También se aplica a clientes cuyo perfil es admin. Las reglas
de áreas/dispositivos se describen abajo; las demás colecciones permanecen cerradas.
El usuario inactivo puede leer su propio perfil
para ver el bloqueo, pero no editarlo.

Para desplegar únicamente estas reglas:

```sh
firebase deploy --only firestore:rules --project ecohome-3c91d
```

Las pruebas de reglas usan un proyecto de demostración local, sin datos reales
y sin nuevas dependencias npm. Requieren Firebase CLI y Java 21 disponible para
ese proceso. En PowerShell puede usarse el Java ya incluido en Android Studio:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
firebase emulators:exec --only firestore --project demo-ecohome-rules --config firebase.rules-test.json "node --test rules-tests/firestore.test.cjs"
```

Esas variables solo afectan a la terminal actual. No se requiere un emulador
Android. Las pruebas de Flutter usan dobles en memoria y conservan las 20 pruebas
de la Fase 4.

### Validación en teléfono

1. Inicia Node con `npm start` dentro de `server`.
2. Conecta el teléfono por USB y ejecuta `flutter devices` desde la raíz.
3. Ejecuta `flutter run -d <ID_TELEFONO> --dart-define=WEBSOCKET_URL=ws://<IP_LOCAL_PC>:8080`
   usando la IPv4 actual de la PC; ambos equipos deben compartir una red accesible.
4. Inicia sesión con una cuenta antigua sin perfil. Comprueba en Firestore que se
   creó `/users/<UID>` como user activo, con correo correcto y timestamps.
5. Cierra y abre sesión: el documento, nombre, rol y createdAt deben conservarse.
6. Registra una cuenta nueva y comprueba el mismo perfil seguro, sin selector de rol.
7. Abre Perfil, edita el nombre y comprueba su persistencia al reiniciar. Los demás
   campos deben conservarse, salvo updatedAt.
8. En Firebase Console, Authentication → Users, copia el UID de la cuenta de prueba.
   En Firestore → `(default)` → `users` → ese UID, verifica el correo y cambia solo
   `role` (string) a `admin`. No cambies UID, correo ni fechas. Perfil debe reflejar
   admin; si es necesario vuelve a entrar. Esto no habilita un panel administrativo.
   Para revertir, cambia el string a `user`. No se promueve ninguna cuenta automáticamente.
9. Desde Console cambia `active` (boolean) a `false`: la app conectada debe mostrar
   Cuenta desactivada, impedir usar el hogar y permitir cerrar sesión. Vuelve a entrar
   y confirma que sigue bloqueada. Restaura `active: true` desde Console.
10. Prueba iniciar con red desactivada: debe bloquear la entrada con error de perfil
    tras el tiempo de espera y ofrecer reintento. Restablece la red y reintenta.
11. Comprueba dispositivos, escenas y alertas con Node activo. Problemas de conexión
    a la IPv4/puerto 8080 pertenecen a WebSocket/red, separados de Firebase.

No borres el documento para simular una desactivación: la compatibilidad crea un
perfil seguro cuando falta. Usa siempre `active: false` para desactivar.

## Núcleo del hogar — Fase 6 optimizada

Áreas y dispositivos se comparten entre los usuarios activos del proyecto; todavía
no hay separación por hogar. Firestore es su única fuente de verdad en Flutter.

- `areas/{areaId}`: name (string), createdAt y updatedAt (timestamp).
- `devices/{deviceId}`: name, type, areaId (string); enabled y online (boolean);
  value y energyConsumption (number); createdAt y updatedAt (timestamp).
- El ID vive en la ruta. areaId referencia un área; si falta, la UI muestra el
  dispositivo bajo “Área no disponible”.
- Tipos: light, fan, airConditioner, camera, lock, television, sensor, outlet, other.
- Luz: enabled y value entero 0–100 (%). Ventilador: enabled y value 1–3.
  Aire: enabled y value 16–30 (°C). Los controles de valor se habilitan al encender.
- Cerradura: enabled=true significa bloqueada. Cámara: enabled=true significa activa.
  Televisión, enchufe y other: encendido/apagado. En estos tipos value permanece 0.
- Sensor: lectura numérica sin controles. El sensor demo representa temperatura.
- energyConsumption queda en 0 como dato simulado reservado (kWh acumulados por
  dispositivo); no se agregaron cálculos, historial ni gráficas nuevas.
- online se administra desde Console; estando offline no se permiten controles.

La UI usa AreaProvider/DeviceProvider → repositorios → FirestoreService. Las
escrituras de control son transacciones con updatedAt del servidor: no se ponen
órdenes en cola offline y la UI espera al stream confirmado, sin cambios optimistas.
Los listeners se cancelan al salir o bloquear el perfil. Los contadores existentes
de luces/cámaras también usan DeviceProvider, sin valores paralelos de Node.

Las reglas exigen un perfil active=true para leer áreas/dispositivos. Solo permiten
modificar enabled/value/updatedAt, con rangos por tipo; sensores no aceptan cambios.
No permiten CRUD ni cambios administrativos a clientes, tampoco por tener role=admin.
La protección de /users se conserva. PERMISSION_DENIED en las pruebas negativas
locales es un rechazo esperado, no un fallo de la prueba.

### Seed explícito (desarrollo)

Usa la sesión autorizada de Firebase CLI instalada por npm en Windows, sin claves
ni dependencias nuevas. Proyecto fijo: ecohome-3c91d. Ejecutar desde la raíz:

```powershell
node scripts/seed_home.cjs
node scripts/seed_home.cjs --apply
```

El primero solo consulta y muestra una vista previa. El segundo crea en una única
transacción cinco áreas y once dispositivos con IDs estables, únicamente si ambas
colecciones están vacías. Si cualquiera contiene datos, no modifica nada. Repetirlo
no duplica ni sobrescribe documentos, y no rellena una base ya personalizada.
No depende del servidor Node ni se ejecuta desde Flutter.

### Validación móvil de esta fase

1. Conecta el teléfono: `flutter devices` y `flutter run -d <ID_TELEFONO>`.
2. Entra con un perfil activo. En Dispositivos abre un área y prueba interruptores,
   intensidad, velocidad, temperatura y cerradura. Sensor no muestra controles.
3. Observa valores y updatedAt en Firebase Console. Cierra/reabre la app:
   los estados deben persistir y reflejarse en otro teléfono/sesión activa.
4. Cambia online a false desde Console: el dispositivo queda sin controles.
   Cambia areaId a otro ID existente desde Console: la agrupación se actualiza.
5. Cambia active=false en tu perfil desde Console: se bloquea el hogar; restaura
   true para continuar. Comprueba errores/reintento al cortar/restaurar la red.
6. Detén Node: áreas, dispositivos y sus controles deben seguir funcionando.
   Para escenas/alertas e indicadores antiguos, inicia Node y usa
   `--dart-define=WEBSOCKET_URL=ws://<IP_LOCAL_PC>:8080` en la misma red.

Validaciones: `dart format .`, `flutter analyze`, `flutter test`,
`flutter build apk --debug --no-pub`, `node --test` en server y las pruebas locales
Firestore Rules indicadas arriba. No se configuró Firebase Web.

## Escenas y Dashboard — Fase 7 optimizada

Esta sección reemplaza la referencia histórica de la Fase 6 a escenas WebSocket.
Flutter ya no consume ni envía escenas por WebSocket. Node conserva su protocolo
antiguo sin ser fuente de verdad de áreas, dispositivos o escenas para la app.
Siguen pendientes únicamente alertas, temperatura/confort, seguridad y energía
legacy. No se añadieron datos de energía ni historial de actividad.

`scenes/{sceneId}` contiene name (string), enabled (boolean), actions (array),
createdAt y updatedAt (timestamp). Cada acción tiene deviceId (string), enabled
(boolean) y value (number opcional). Se permiten 1–20 acciones con IDs distintos.
enabled en la escena significa disponible; no se escribe un active permanente,
ni se cambia su updatedAt al ejecutarla.

SceneProvider → SceneRepository → FirestoreService ejecuta una transacción que
relee la escena y todos sus dispositivos, valida acciones y después escribe solo
enabled/value/updatedAt. Si cualquier referencia falta, está offline, es un sensor
o recibe un valor incompatible, la operación completa falla sin escrituras parciales.
La transacción no se encola offline. El stream de dispositivos actualiza la UI.
La ejecución simultánea local se bloquea y se muestra éxito o error; otros clientes
pueden seguir controlando dispositivos. Las transacciones resuelven conflictos y
el último control confirmado define el estado, sin bloquear permanentemente el hogar.

Escenas demo:

- Modo Noche: apaga luces y deja la auxiliar de Recámara al 15%; bloquea Patio y activa cámara.
- Modo Casa: enciende luces principales de Sala, Cocina y Recámara; mantiene cerradura bloqueada y cámara activa.
- Modo Away: apaga luces, ventilador y aire; bloquea cerradura y activa cámara.
- Ahorro de Energía: deja Luz Sala al 30%, apaga las otras luces, ventilador y aire.

Seed de escenas, independiente del seed original del hogar:

```powershell
node scripts/seed_home.cjs --scenes
node scripts/seed_home.cjs --scenes --apply
```

El primero es una vista previa. El segundo añade únicamente las escenas demo que
faltan, con IDs estables y en una transacción. Conserva toda escena existente y no
modifica áreas ni dispositivos. Aborta si una escena pendiente referencia un ID
demo inexistente o cuyo tipo fue cambiado. Nunca corre al arrancar Flutter.

El Dashboard deriva dispositivos totales, activos (enabled=true), offline, áreas,
luces y cámaras de los providers Firestore; ofrece botones de ejecución de escenas.
Los contadores cuentan estados simulados, no confirman hardware. Seguridad y energía
se identifican como prototipo; temperatura sigue usando la lectura legacy.

Las reglas permiten leer escenas a perfiles activos y deniegan toda escritura de
configuración desde clientes, incluso admin. Ejecutar utiliza los permisos de control
ya existentes en devices. Como el usuario también puede controlar dispositivos
individualmente, las reglas no imponen que un conjunto de controles provenga de
una escena; sí restringen siempre campos y rangos. /users y /areas siguen protegidos.

Prueba física: `flutter devices`, luego `flutter run -d <ID_TELEFONO>`. Con Node
detenido, abre Escenas y aplica cada configuración; comprueba cambios simultáneos
en Dispositivos y los contadores del Dashboard. Cierra/reabre y verifica persistencia
de dispositivos (no hay una escena permanentemente “activa”). Cambia online=false
en camera_patio desde Console, ejecuta Modo Away y comprueba el error y que ninguna
otra acción se aplicó; restáuralo a true. Comprueba listeners con otra sesión o
cambios desde Console. Node solo es necesario para las funciones legacy indicadas.

## Energía e historial — Fase 8 optimizada

Esta fase reemplaza la unidad provisional de energyConsumption documentada en
Fase 6 y elimina la energía legacy de Flutter. Device.energyConsumption representa
ahora potencia nominal simulada en **W**. Los registros usan **Wh**, sin confundir
potencia con energía: Wh = W × horas. No se modelan variaciones por intensidad,
velocidad o temperatura; la potencia efectiva es nominal si enabled y online son
true, o cero en caso contrario. No son mediciones de hardware.

`energy_records/{deviceId}_{díaUTC}` contiene:

- deviceId, areaId: identidad y área al tomar la muestra.
- powerWatts: potencia efectiva utilizada para reproducir el cálculo.
- durationHours: 1, intervalo hipotético fijo de la simulación.
- consumption: energía estimada de ese intervalo en Wh.
- recordedAt: timestamp del servidor al crear la muestra.

La pestaña Energía tiene un botón explícito **Simular 1 hora**. No existe un timer
que genere datos: como máximo crea una muestra por dispositivo y día UTC, compartida
por todos los usuarios del proyecto. Se utiliza el estado actual, no se pretende
reconstruir el consumo real transcurrido. Repetir el botón u operar desde otro
teléfono no sobrescribe ni duplica la muestra. El día del ID se valida contra la
hora del servidor, por lo que un reloj de teléfono incorrecto puede causar rechazo.
Cada dispositivo tiene su propia transacción; una interrupción puede dejar un
subconjunto creado, y reintentar completa los faltantes sin duplicar los existentes.

La pantalla y el Dashboard muestran el total de las muestras de hoy UTC y de los
últimos siete días UTC, no una estimación continua de 24 horas por día. Incluye
agrupación histórica por área y dispositivo y barras diarias solo para días con
registros. No se inventan días faltantes ni se genera historia ficticia para la
gráfica. La ventana se actualiza al cambiar el día. No se agregó ninguna dependencia.

Potencias demo: luces 9 W, ventilador 60 W, aire 1200 W, cámara 8 W, cerradura 2 W,
sensor 1 W. El seed original utiliza estos valores para bases nuevas. Para completar
los dispositivos existentes que aún tienen cero:

```powershell
node scripts/seed_home.cjs --powers
node scripts/seed_home.cjs --powers --apply
```

La primera ejecución es una vista previa. El modo apply actualiza únicamente la
potencia en cero y updatedAt de IDs demo con el tipo esperado. No sobrescribe valores
no nulos personalizados, no cambia controles y no crea registros energéticos.
Esta inicialización se ejecutó sobre los 11 dispositivos demo existentes.

`activity/{activityId}` contiene userId, action, entityType, entityId, description
y createdAt del servidor. action es device_control o scene_executed; entityType
es device o scene. Un control manual de enabled/value crea un evento; una escena
exitosa crea un solo evento, no uno por cada dispositivo. No se guardan credenciales.
La referencia del evento se genera fuera de la transacción para evitar duplicarlo
en reintentos internos. Los dispositivos y su evento se confirman en la misma
transacción: un rechazo del evento también aborta los controles. Los fallos no
generan eventos de éxito. El botón solo informa éxito después de la confirmación.

Perfil → Mi actividad muestra únicamente las últimas 50 acciones del usuario,
ordenadas por createdAt descendente. El índice userId ASC / createdAt DESC se define
en firestore.indexes.json. Los listeners se eliminan al cerrar o bloquear la sesión.
El historial es generado por la aplicación cliente; no es una auditoría privilegiada
independiente del cliente. Las reglas atribuyen eventos al UID autenticado, validan
esquema/referencia y prohíben edición/borrado. Para controles exigen además updatedAt
del dispositivo en la misma operación; no exigen historial a clientes antiguos.

Reglas energy_records: lectura de usuarios activos; creación con esquema exacto,
potencia/área del dispositivo, cálculo válido, timestamp servidor e ID canónico diario.
No permiten modificar ni borrar muestras ni escoger otra potencia/duración. Activity
exige usuario activo, UID propio para leer/crear y consultas de hasta 50 registros.
No hay vista global admin ni CRUD nuevo. Usuarios, áreas, dispositivos y escenas
mantienen sus protecciones anteriores.

Despliegue de esta fase:

```powershell
firebase deploy --only "firestore:rules,firestore:indexes" --project ecohome-3c91d
```

El cálculo del día usa [Timestamp.toMillis](https://firebase.google.com/docs/reference/rules/rules.Timestamp)
y las operaciones usan [transacciones Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions).

Prueba física:

1. `flutter devices`; `flutter run -d <ID_TELEFONO>` con una cuenta activa.
2. Cambia enabled y value de dispositivos y ejecuta una escena. Perfil → Mi actividad
   debe mostrar los controles y un evento por escena exitosa, recientes primero.
3. Provoca una escena fallida con un dispositivo offline: no debe crear actividad.
4. En Energía pulsa Simular 1 hora. Comprueba Wh, área/dispositivo, barra de hoy y
   Dashboard; repetir no cambia los registros ya creados. Reabre para verificar persistencia.
5. Entra con otra cuenta: energía compartida, actividad propia. No se registra login.
6. Con Node detenido, energía/actividad/dispositivos/escenas siguen funcionando.
   Node conserva solo alertas, temperatura/confort y seguridad del prototipo.

No se implementaron FCM, Firebase Web, administración, multi-hogar ni Cloud Functions.

## Fase 9 — Administración y seguridad (estado vigente)

Este apartado sustituye las restricciones históricas de fases anteriores sobre
administración. Perfil muestra Administración únicamente cuando `/users/{uid}`
tiene `role: admin` y `active: true`. No hay UID ni correo privilegiado en código.
El panel permite:

- Usuarios: listar perfiles y cambiar rol/estado de otras cuentas. No crea ni
  elimina cuentas Authentication y no modifica identidad, correo o contraseñas.
  Los usuarios siguen registrándose mediante el flujo Authentication existente.
- Áreas: crear, renombrar y eliminar cuando no contienen dispositivos.
- Dispositivos: crear, editar y eliminar; nombre, tipo, área, potencia en W,
  online, enabled y value. Potencia entre 0 y 100000 W, coherente con energía.
- Escenas: crear, editar, habilitar/deshabilitar y eliminar; entre 1 y 20 acciones
  sobre dispositivos distintos, existentes y compatibles. Se pueden preparar
  escenas con dispositivos offline; ejecutarlas requiere que estén online.
- Actividad global: las últimas 100 actividades, con UID, tipo, descripción y fecha.
  Mi actividad conserva la consulta propia de 50 registros.

`AdminScreen → AdminProvider → AdminRepository → AdminService` reutiliza perfiles
existentes y la validación de compatibilidad de `Scene`. Las reglas consultan el
perfil autenticado para conceder permisos; ocultar la UI no concede autorización.
La aplicación y las reglas bloquean cambiar el rol/estado del propio administrador.
Cambiar a user o active=false cancela listeners, limpia datos administrativos y
bloquea los formularios abiertos. ProfileGate sigue bloqueando cuentas inactivas.

El servicio comprueba referencias antes de escribir: un área ocupada no se borra;
un dispositivo usado por cualquier escena, incluso deshabilitada, tampoco.
Cambiar el tipo de un dispositivo no puede invalidar sus escenas. Cada operación
lee y actualiza `_admin/catalog` (revision y updatedAt) en su transacción, para que
operaciones concurrentes del panel vuelvan a consultar y validar el catálogo.
No es una colección de datos del hogar; solo administradores activos acceden a ella.
Las comprobaciones de referencias cruzadas viven en el servicio; las reglas
validan autorización, esquema, timestamps y área existente del dispositivo.
Las modificaciones directas desde Firebase Console eluden estas comprobaciones:
realizar el CRUD desde el panel y reservar Console para recuperar permisos.

La mutación y su evento se confirman juntos, con timestamps del servidor. Los
reintentos reutilizan el ID del evento; los fallos no registran éxito. Los eventos
nuevos usan action `admin_create`, `admin_update` o `admin_delete`, y entityType
`users`, `areas`, `devices` o `scenes`. Los cambios de perfil describen rol y estado.
El historial permanece inmutable incluso para admin; no es una auditoría externa
independiente de clientes privilegiados. Energía mantiene sus reglas anteriores.
No hay permisos nuevos sobre alertas ni sobre el resto de colecciones.

La consulta global ordena por createdAt descendente y usa el índice simple de
Firestore; no requiere un índice compuesto nuevo. Se conserva el índice compuesto
userId/createdAt de Mi actividad. Las transacciones y sus límites están descritos
por [Firebase](https://firebase.google.com/docs/firestore/manage-data/transactions).

Validación automatizada: `test/admin_test.dart`, `test/admin_service_test.dart`
y casos administrativos añadidos a `rules-tests/firestore.test.cjs`. Las pruebas
Firestore usan exclusivamente `demo-ecohome-rules` en 127.0.0.1:8085; no crean datos
reales. Los archivos `tmp/phase9-*.log` conservan resultados de esta ejecución.

Prueba mínima en teléfono Android físico:

1. Si necesitas preparar la cuenta de prueba, en Firebase Console → Firestore →
   users → su UID, establece manualmente role="admin" y active=true; conserva
   uid, email, nombre y timestamps. No cambia Authentication ni otros perfiles.
2. Conecta el teléfono y autoriza depuración USB: `flutter devices`, después
   `flutter run -d <ID_TELEFONO>`. Si pruebas también Node, añade
   `--dart-define=WEBSOCKET_URL=ws://<IP_LOCAL_PC>:8080`; nunca fijes esa IP en código.
3. Entra como admin: Perfil → Administración. Crea un área y un dispositivo;
   configura una escena, edítala, deshabilítala y verifica que no se ejecuta.
4. Intenta borrar el área ocupada y el dispositivo usado: deben explicar el bloqueo.
   Elimina primero la escena, luego el dispositivo y finalmente el área de prueba.
5. Con una segunda cuenta, cambia rol/active desde Usuarios. Comprueba el bloqueo
   de la propia cuenta y los eventos globales; no uses tu única cuenta para revocarte.
6. Entra como user: Administración no aparece; controles, escenas, energía y
   actividad propia siguen funcionando. Desactiva esa cuenta desde el administrador
   y confirma el bloqueo. Rehabilítala para continuar.
7. Con otro administrador o desde Console, cambia a user el perfil de un admin
   que tenga el panel abierto: debe perder acceso. Repite con active=false.

La aceptación visual y contra Firebase real queda para el teléfono; no se requiere
emulador Android. WebSocket/Node, alertas, temperatura y seguridad legacy permanecen
sin migrar. No se incluyen FCM, Firebase Web, Cloud Functions, Admin SDK ni otra fase.

Cierre automatizado de Fase 9 (2026-09-25): formato aplicado, análisis sin incidencias,
74 pruebas Flutter aprobadas (19 nuevas), 46 pruebas locales de reglas aprobadas
(9 adicionales contando el grupo), 1 prueba Node aprobada y APK debug compilada.
Las reglas se desplegaron realmente a ecohome-3c91d y se compararon byte a byte:
ruleset `76960b21-1e3b-4995-83e0-6c91399f595b`. Evidencia:
`tmp/phase9-verification.json`. La consulta global real funcionó y el índice
compuesto previo sigue READY. No se crearon documentos de prueba en producción.
La compilación conserva la advertencia previa de futura compatibilidad Kotlin
(KGP) en plugins Firebase; no impidió compilar ni se actualizaron herramientas.
Queda pendiente únicamente la validación funcional/visual en teléfono físico.

## Fase 10 — Alertas Firestore y recepción FCM (vigente)

`NotificationProvider → NotificationRepository → FirestoreService` sustituye a
EcoHomeState/WebSocket. `/alerts/{id}` contiene title, message, type=device_offline,
userId, read, createdAt servidor y deviceId. La campana muestra las últimas 100
propias y el badge cuenta las no leídas dentro de esa ventana. Marcar como leída
solo cambia read a true; nadie puede editar contenido, cambiar propietario o borrar.

**Comprobar dispositivos** crea alertas simuladas propias para cámaras/cerraduras
offline. Las reglas verifican el dispositivo y el mensaje derivado de su nombre;
el ID uid_deviceId_díaUTC y la transacción evitan duplicados diarios y sobrescrituras.
No se generan en listeners, en background ni al recibir push. Una operación parcial
puede reintentarse: conserva lo ya creado. Un reloj del teléfono incorrecto puede
provocar rechazo por el día UTC; se usa fecha/hora automática en Android.

Seguridad simulada = existe al menos una cerradura y cámara, y todas están online
y habilitadas/bloqueadas; si no, Revisar. No es seguridad física real. Se retiró
la temperatura decorativa: el value del AC es una consigna, no medición ambiental,
y los sensores genéricos no declaran unidad. No se crea otra colección.

FCM Android usa firebase_messaging 16.7.0, permiso explícito, renovación de token,
SnackBar en foreground y apertura de Notificaciones desde un push (después del
Auth/Profile Gate si hace falta). Android presenta el payload notification en
segundo plano. Un push de prueba NO crea un registro Firestore ni cambia el badge.
No hay backend emisor, credenciales administrativas ni registro propio de tokens:
el SDK gestiona cada instalación y Flutter conserva el token en memoria, sin logs
ni UI. No se vincula al UID; los push de Console pueden llegar con sesión cerrada.
Usar mensajes de prueba genéricos, nunca contenido privado de una cuenta.

Prueba física mínima:
1. Detén Node. Conecta Android/USB, `flutter devices` y `flutter run -d <ID>`.
   Ya no hay WEBSOCKET_URL ni IP local. Prueba dispositivos, escenas, energía y actividad.
2. Comprueba Seguridad simulada al activar/desactivar cerradura/cámara; no hay tarjeta
   de temperatura. Como admin, deja temporalmente una cámara offline.
3. Como usuario, campana → Comprobar dispositivos: aparece alerta y badge. Repite
   sin duplicar; marca leída y verifica persistencia y badge al reabrir. Otra cuenta
   no ve esa alerta. Restablece online desde el panel administrativo.
4. En Notificaciones, pulsa Activar notificaciones push y acepta Android. Si ya se
   denegó definitivamente, habilita el permiso desde Ajustes → EcoHome → Notificaciones.
5. Para obtener el token sin mostrarlo en la app: ejecuta/adjunta el depurador Flutter
   de VS Code, pon un breakpoint en `_register` de `lib/services/push_service.dart`,
   en la asignación `status` inmediatamente después de `await getToken()`. Pulsa
   Activar notificaciones push, inspecciona `debugToken` o `_token`, cópialo y continúa.
6. Firebase Console → ecohome-3c91d → Messaging → crear notificación (título y texto)
   → Enviar mensaje de prueba → pega el token de registro FCM → Probar.
   No publiques una campaña general. Repite con app visible: debe mostrar SnackBar.
7. Repite con app en segundo plano: debe aparecer notificación Android; tócala y
   verifica que abre Notificaciones. Repite cerrando la app desde recientes, sin
   forzar detención en Ajustes. Si Android fuerza detención, abre la app primero.

FCM real requiere teléfono con Google Play Services y conectividad; está pendiente
esa aceptación física. Implementación basada en la [guía oficial de recepción FCM](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
server/ permanece sin cambios y ya no forma parte de las validaciones habituales.

Cierre automatizado Fase 10: formato correcto, flutter analyze sin incidencias,
74 pruebas Flutter aprobadas (adaptadas al retiro del estado legacy), 52 pruebas
locales de reglas aprobadas y APK debug compilada. Node pasó su última prueba (1).
Reglas e índice de alertas desplegados en ecohome-3c91d; contenido remoto idéntico,
índice READY y consulta real verificada. Evidencia: `tmp/phase10-verification.json`.
No se crearon alertas de prueba en producción. Queda pendiente la validación física
FCM/UI. La advertencia existente de futura compatibilidad Kotlin y avisos de APIs
obsoletas de plugins no impidieron compilar; no se actualizaron herramientas.

## Inicio de sesión con Google (Android)

Login ofrece **Continuar con Google**, además de correo/contraseña, registro y
recuperación. Usa `google_sign_in: 7.2.0` y Firebase Authentication mediante las
capas existentes; la sesión sigue dependiendo del Auth Gate, no del selector Google.
La inicialización usa el OAuth de `android/app/google-services.json`, sin claves
secretas ni configuración Firebase Web. El archivo actualizado incluye clientes
Android y OAuth tipo 3, necesario para obtener el ID token.

Los perfiles nuevos usan displayName (recortado a 80 caracteres) o el nombre del
correo como alternativa, siempre role=user y active=true. El UID lo determina
Firebase. La transacción existente no sobrescribe ningún perfil: conserva también
nombre, role, active y createdAt. Un perfil inactivo sigue bloqueado por ProfileGate.
No se vinculan credenciales ni se fusionan perfiles por correo desde EcoHome; ante
un conflicto Firebase se indica entrar con el método original. Cancelar el selector
no muestra error y libera los botones. Cerrar sesión cierra Firebase y limpia la
sesión Google cuando se ha inicializado, sin desconectar/revocar permisos globales.

Prueba: conecta el teléfono, `flutter devices`, `flutter run -d <ID>`; en Login
pulsa Continuar con Google y elige una cuenta. Revisa Perfil, cierra/reabre la app
para comprobar persistencia y cierra sesión. Cancela otro intento y verifica que
correo/contraseña sigue funcionando. Con un perfil existente comprueba que el rol
se conserva; prueba active=false mediante otra cuenta admin y restablécelo después.
La prueba real del selector/credenciales requiere Android físico con servicios de
Google; no se ejecutó desde Codex. [API oficial utilizada](https://pub.dev/packages/google_sign_in).
