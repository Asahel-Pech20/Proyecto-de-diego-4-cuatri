# Participación y contribuciones por integrante — MiSemestre UTM

> Evidencia de responsabilidades, archivos implementados y decisiones técnicas por integrante del equipo (Sección 2 y 8 de los lineamientos).

## 1. Resumen de contribuciones del equipo

| Integrante | Rol en el equipo | Aportación principal y módulos implementados | Estado |
|---|---|---|---|
| **Santiago Asahel Pech Ake** | Lógica/servicios, sincronización e integración | Servicios de cliente API, base local SQLite, protocolo de sincronización offline (`SyncService`), notificaciones locales (`NotificationService`), proveedores de estado y corrección de incidencias **I-5**, **I-6** e **I-7** | ✅ |
| **Nataly Marisol Santos Miam** | Interfaz móvil (Flutter) y documentación | Pantallas de la app (Inicio, Horario, Tareas con cámara, Materias, Faltas en 1 toque, Simulador, Guía de batería y Ajustes), diseño responsivo (**I-1**), ícono adaptativo propio (**I-4**), bocetos y manual de usuario | ✅ |
| **Oscar Michel Matos May** | Base de datos, seguridad y pruebas del backend | Esquema PostgreSQL con borrado lógico, autenticación JWT + bcrypt, aislamiento por usuario dueño (`WHERE user_id = $1`), validación Zod, protección de fotos, pruebas `smoke.js` / `rate-limit.js`, bitácora y modelo de seguridad | ✅ |
| **Genaro Aurelio Antonio Pacheco** | Pruebas, APK firmado, widget nativo y versión web | Aplicación web en React + Vite (**I-2**), proveedor del widget nativo Android en Kotlin, firma de distribución del APK (**I-3**), suite de pruebas automatizadas (49 app / 18 web), matriz de validación, evidencias y presentación pitch | ✅ |

---

## 2. Código y decisión técnica que expone cada integrante

### Santiago Asahel Pech Ake — Sincronización sin conexión y notificaciones locales
- **Archivos clave:**
  - `app/lib/services/sync_service.dart`
  - `app/lib/services/database_service.dart`
  - `app/lib/services/notification_service.dart`
  - `app/lib/providers/absence_provider.dart`
- **Decisión técnica:**
  - **Sincronización incremental jerárquica (*offline-first*):** Todas las operaciones escriben primero en SQLite con estados `pending_create`, `pending_update` o `pending_delete`. Al recuperar la red, `SyncService` envía primero las materias nuevas antes que sus horarios, tareas, faltas o evaluaciones para respetar las llaves foráneas, y luego descarga deltas con `GET /api/sync?since=<timestamp>` sin sobrescribir cambios locales pendientes.
  - **Confiabilidad de alertas de asistencia (I-7):** `showImmediateNotification` comprueba `areNotificationsEnabled()` en Android y devuelve `Future<bool>`, de modo que `_checkAndNotifyAbsenceAlerts` solo marca la alerta como enviada en `SharedPreferences` cuando la notificación realmente pudo mostrarse al estudiante.

### Nataly Marisol Santos Miam — Experiencia móvil, captura en clase e identidad visual
- **Archivos clave:**
  - `app/lib/screens/home/home_screen.dart`
  - `app/lib/screens/tasks/task_form_dialog.dart`
  - `app/lib/screens/subjects/subject_detail_screen.dart`
  - `app/lib/screens/auth/login_screen.dart` y `register_screen.dart`
  - `docs/analisis-diseno.md` y `docs/manual-usuario.md`
- **Decisión técnica:**
  - **Captura rápida contextual en ≤ 3 toques:** Al abrir el formulario de nueva tarea durante una clase en curso, la app detecta automáticamente la materia actual según el horario y preselecciona como fecha de entrega la próxima sesión de esa materia, permitiendo adjuntar una foto del pizarrón con la cámara en segundos.
  - **Adaptabilidad visual y estados claros:** Se eligió la identidad visual Vino UTM (`#7A1B29`) y Dorado (`#D49E35`) con alto contraste, etiquetas explícitas de `Pendiente sync` para evitar falsas confirmaciones sin red y contenedores `Wrap` en autenticación (**I-1**) para evitar desbordes en pantallas angostas o con fuente ampliada.

### Oscar Michel Matos May — Modelo de datos, aislamiento en servidor y seguridad
- **Archivos clave:**
  - `backend/src/schema.sql`
  - `backend/src/routes/resource.js` y `backend/src/routes/uploads.js`
  - `backend/src/schemas.js` y `backend/src/middleware/auth.js`
  - `backend/test/smoke.js` y `backend/test/rate-limit.js`
  - `docs/datos-seguridad.md` y `docs/bitacora.md`
- **Decisión técnica:**
  - **Control de acceso en servidor y borrado lógico:** En lugar de ocultar botones en el cliente, todas las consultas SQL del backend filtran por `WHERE user_id = $1` extraído del token JWT firmado, y verifican que la materia pertenezca al usuario antes de insertar registros hijos (respondiendo `404` ante cualquier intento de acceso cruzado, comprobado con dos usuarios en `smoke.js`).
  - **Protección de credenciales y archivos:** Las contraseñas se almacenan con `bcrypt` (costo 10), los endpoints de autenticación tienen límite de intentos (`express-rate-limit`), y las fotos se validan por tipo MIME (`JPG/PNG/WEBP/HEIC`) y tamaño (máx. 5 MB), guardándose con prefijo `<userId>-<uuid>` para que ningún otro usuario autenticado pueda descargarlas.

### Genaro Aurelio Antonio Pacheco — Ecosistema Web/Móvil, Widget Android, pruebas y empaquetado APK
- **Archivos clave:**
  - `app/android/app/src/main/kotlin/mx/utm/app/MiSemestreWidgetProvider.kt`
  - `app/android/app/build.gradle.kts`
  - `app/test/` (10 archivos, 49 pruebas) y `web/src/` (18 pruebas)
  - `docs/pruebas.md`, `docs/web-vs-movil.md` y `docs/apk-firma.md`
- **Decisión técnica:**
  - **Complementariedad real entre Web y Móvil (Modalidad B):** La versión web en React está optimizada para la planeación inicial del cuatrimestre en pantalla grande, mientras que la app Flutter agrega capacidades exclusivas del dispositivo: widget nativo en pantalla de inicio, cámara, alarmas locales sin conexión y base SQLite local.
  - **Firma de distribución segura fuera del repositorio:** Se configuró `signingConfigs.release` en Gradle leyendo `key.properties` (excluido por `.gitignore`) y una keystore RSA-2048 propia (`CN=MiSemestre UTM`) resguardada fuera del árbol de Git para generar un APK instalable con identidad propia (`mx.utm.app`).
