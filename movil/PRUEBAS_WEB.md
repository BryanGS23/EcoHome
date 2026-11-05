# Probar EcoHome en el navegador

Abre `ABRIR_EN_NAVEGADOR.bat` con doble clic. Chrome se abre al terminar la preparación. Mantén abierta la ventana de ejecución mientras pruebas la app. Para detenerla, presiona Ctrl+C en esa ventana.

También puedes ejecutar `flutter run -d chrome --web-port 7357` desde esta carpeta.

La versión web usa el mismo proyecto Firebase que Android: las cuentas y los cambios de datos son reales y se comparten con la app móvil.

Puedes probar el acceso con correo, el registro, las pantallas y las funciones correspondientes a tu cuenta. El acceso con Google usa una ventana emergente; si Firebase muestra `unauthorized-domain`, agrega `localhost` en Firebase Console > Authentication > Settings > Authorized domains.

Las notificaciones dentro de la app siguen disponibles. Las notificaciones push quedan reservadas para Android; la versión web todavía no configura el service worker ni las claves web push.
