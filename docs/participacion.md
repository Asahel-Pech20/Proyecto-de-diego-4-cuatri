# Participación: un commit de cada integrante

El docente revisa la participación **por autor de commit** en GitHub. Cada integrante hace su propio
commit, con su cuenta, de la parte que le toca según los roles de [propuesta.md](propuesta.md).
Todo se puede hacer **desde el navegador**, sin instalar nada: abrir el archivo en GitHub → ✏️ *Edit* →
pegar el cambio → *Commit changes*.

| Integrante | Rol | Su commit | Estado |
|---|---|---|---|
| Genaro Aurelio Antonio Pacheco | Pruebas, APK y versión web | PR #1: ícono, firma, APK, pruebas, evidencias, presentación | ✅ |
| Santiago Asahel Pech Ake | Lógica/servicios, integración y repositorio | Revisar y hacer *merge* del PR #1 + corregir la incidencia I-7 | ✏️ |
| Nataly Marisol Santos Miam | Interfaz de la app y documentación | Probar el APK en su teléfono y subir las capturas | ✏️ |
| Oscar Michel Matos May | Base de datos y seguridad, pruebas del backend | Bitácora de reuniones y fuente de la información | ✏️ |

---

## Santiago: merge del PR y corrección de I-7

1. En GitHub → *Pull requests* → **#1** → revisar → **Merge pull request**. Como dueño del repo, el *merge* queda a su nombre.
2. Corregir I-7: la alerta de faltas se marca como "enviada" aunque Android la haya bloqueado por falta de permiso.

`app/lib/services/notification_service.dart`: cambiar `showImmediateNotification` para que devuelva si se mostró:

```dart
  Future<bool> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    lastImmediateNotifications.add({'id': id, 'title': title, 'body': body});
    try {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled() ?? true;
      if (!enabled) return false;
      const androidDetails = AndroidNotificationDetails(
        'misemestre_alerts',
        'Alertas de Asistencia',
        channelDescription: 'Avisos de límite de faltas de materias',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      return true;
    } catch (e) {
      debugPrint('Error mostrando notificación inmediata: $e');
      return false;
    }
  }
```

`app/lib/providers/absence_provider.dart`, en `_checkAndNotifyAbsenceAlerts`: guardar la marca solo si se mostró
(en los dos bloques, el de "superado" y el de "en riesgo"):

```dart
        final shown = await NotificationService.instance.showImmediateNotification(...);
        if (shown) await prefs.setBool(exceededKey, true);   // y igual con warningKey
```

Probar con `flutter test` y, en `docs/pruebas.md`, cambiar I-7 de **Abierta** a **Corregida**.
Mensaje del commit: `Corrige I-7: la alerta de faltas se repite si no había permiso de notificaciones`.

## Nataly: prueba en teléfono físico

1. Instalar `MiSemestre-UTM-v1.2.0.apk` en su teléfono (permitir la instalación solo para ese archivo).
2. Con la PC y el teléfono en la misma Wi-Fi, en la app → *Configurar servidor* → `http://<IP-de-la-PC>:3000`.
3. Tomar capturas:
   - `telefono-instalada.png`: el ícono en el cajón de apps.
   - `telefono-widget.png`: el widget en la pantalla de inicio.
   - `telefono-recordatorio.png`: crear una tarea para dentro de 15 min con aviso de 10 min, poner modo avión y esperar la notificación.
   - `telefono-reinicio.png`: los datos siguen después de reiniciar el teléfono.
4. En GitHub → `docs/evidencias/` → *Add file → Upload files* → subir las capturas con el prefijo `2026-11-23_`.
5. En `docs/pruebas.md`, cambiar a ✅ las filas *Función móvil* (recordatorio y widget) y *Persistencia* (reinicio).

Mensaje del commit: `Agrega evidencias de prueba en teléfono físico`.

## Oscar: bitácora y fuente de la información

1. `docs/bitacora.md`: en cada versión, reemplazar `✏️ Asistentes / acuerdos / quién hizo qué` con lo que realmente
   se acordó (fecha, quién asistió y qué hizo cada uno; usar la tabla de roles como guía).
2. `docs/propuesta.md`, sección *Fuente de la información*: anotar con cuántos compañeros hablaron, la fecha,
   las respuestas principales y el criterio de faltas de la universidad.

Mensaje del commit: `Completa bitácora de reuniones y fuente de la información`.
