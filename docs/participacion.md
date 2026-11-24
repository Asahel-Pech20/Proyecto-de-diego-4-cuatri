# Participación y contribuciones por integrante — MiSemestre UTM

> Evidencia de responsabilidades, módulos implementados, trazabilidad de commits y decisiones técnicas por integrante del equipo (Secciones 2 y 8 de los lineamientos).

## 1. Resumen de contribuciones del equipo

| Integrante | Rol en el equipo | Aportación principal y módulos implementados | Historias e incidencias | Estado |
|---|---|---|---|---|
| **Santiago Asahel Pech Ake** | Lógica/servicios, sincronización e integración | Servicios de cliente API, base local SQLite, protocolo de sincronización offline (`SyncService`), notificaciones locales (`NotificationService`), proveedores de estado y administración del repositorio | HU3, HU7 · **I-5**, **I-6**, **I-7** | ✅ |
| **Nataly Marisol Santos Miam** | Interfaz móvil (Flutter) y documentación | Pantallas de la app (Inicio, Horario, Tareas con cámara, Materias, Faltas en 1 toque, Simulador, Guía de batería y Ajustes), diseño responsivo, ícono adaptativo propio, bocetos, guía visual y manual de usuario | HU1, HU2, HU4, HU5 · **I-1**, **I-4** | ✅ |
| **Oscar Michel Matos May** | Base de datos, seguridad y pruebas del backend | Esquema PostgreSQL con borrado lógico, autenticación JWT + bcrypt, aislamiento por usuario dueño (`WHERE user_id = $1`), validación Zod, protección de fotos, pruebas `smoke.js` / `rate-limit.js`, bitácora y modelo de seguridad | HU8, HU9 · Seguridad API y BD | ✅ |
| **Genaro Aurelio Antonio Pacheco** | Pruebas, APK firmado, widget nativo y versión web | Aplicación web en React + Vite, proveedor del widget nativo Android en Kotlin, firma de distribución del APK, suite de pruebas automatizadas (49 app / 18 web), matriz de validación, evidencias y presentación pitch | HU6 · **I-2**, **I-3** | ✅ |

---

## 2. Organización del trabajo y trazabilidad en Git

El desarrollo se realizó mediante sesiones de trabajo colaborativo y **programación en parejas (*Pair Programming*)** sobre las dos estaciones de cómputo del equipo que contaban con el entorno completo instalado (Docker Engine + PostgreSQL + Flutter SDK + Android SDK + Emulador Android 15):

| Versión / Rango de commits | Estación de integración | Trabajo integrado y participación por integrante |
|---|---|---|
| **v1.0.0** (`9fad657`) | Estación 1 (`SantiagoAsahel`) | • **Oscar Michel Matos May:** Diseño e implementación de `backend/src/schema.sql`, middleware JWT (`auth.js`), validaciones Zod (`schemas.js`), rutas protegidas por `user_id` (`resource.js`, `uploads.js`) y configuración de seguridad (`helmet`, `express-rate-limit`).<br>• **Nataly Marisol Santos Miam:** Diseño e implementación de las pantallas principales en Flutter (`home_screen.dart`, `schedule_screen.dart`, `tasks_screen.dart`, `task_form_dialog.dart`, `subjects_screen.dart`, `subject_detail_screen.dart`) y paleta Vino/Dorado UTM.<br>• **Santiago Asahel Pech Ake:** Implementación de `api_service.dart`, `database_service.dart` (SQLite), `sync_service.dart`, proveedores (`providers/`) y corrección de **I-6**.<br>• **Genaro Aurelio Antonio Pacheco:** Desarrollo del cliente web en React (`web/src/`) y pruebas unitarias del calculador académico. |
| **v1.1.0** (`f0ba7c3`) | Estación 1 (`SantiagoAsahel`) | • **Santiago Asahel Pech Ake:** Programación de alarmas exactas en `notification_service.dart`, reprogramación al reiniciar Android y corrección del selector de hora (**I-5**).<br>• **Nataly Marisol Santos Miam:** Pantalla de guía de batería (`battery_guide_screen.dart`), pantalla de ajustes (`settings_screen.dart`) y diálogo de borrado de cuenta con confirmación (`BORRAR`).<br>• **Oscar Michel Matos May:** Endpoint `DELETE /api/me` con limpieza transaccional de registros y archivos, pruebas de aislamiento en `backend/test/smoke.js` y `rate-limit.js`, y script `seed-demo.js`.<br>• **Genaro Aurelio Antonio Pacheco:** Widget nativo Android en Kotlin (`HomeScreenWidgetProvider.kt`), `home_widget_service.dart` y pruebas de widgets/sincronización. |
| **v1.2.0** (`6a847c4` .. `HEAD`, PR #1 y #2) | Estación 2 (`Gaap72`) / Merge por `Asahel-Pech20` | • **Nataly Marisol Santos Miam:** Corrección de desborde responsivo con `Wrap` en login/registro (**I-1**, `330917f`), diseño del ícono adaptativo propio (**I-4**, `6a847c4`), redacción de `docs/analisis-diseno.md` y `docs/manual-usuario.md`.<br>• **Oscar Michel Matos May:** Ejecución y validación de las 13 pruebas de backend en Docker (`2026-11-23_backend-tests.txt`), documentación de `docs/datos-seguridad.md`, levantamiento de requerimientos en `docs/propuesta.md` y registro de `docs/bitacora.md`.<br>• **Santiago Asahel Pech Ake:** Corrección de la incidencia **I-7** en `notification_service.dart` y `absence_provider.dart` (`f3990ec`), revisión de código e integración en `main` (`2b5cae5`).<br>• **Genaro Aurelio Antonio Pacheco:** Configuración de firma release (**I-3**, `6a847c4`), sincronización de lockfile web (**I-2**, `31aa45a`), pruebas de validación (`form_validation_test.dart`), evidencias en `docs/evidencias/` (`440d5f2`), `docs/pruebas.md`, `docs/web-vs-movil.md` y presentación pitch (`593de58`). |

---

## 3. Código y decisión técnica que expone cada integrante en la presentación

### Santiago Asahel Pech Ake — Sincronización sin conexión y notificaciones locales
- **Archivos que demuestra:**
  - `app/lib/services/sync_service.dart`
  - `app/lib/services/database_service.dart`
  - `app/lib/services/notification_service.dart`
  - `app/lib/providers/absence_provider.dart`
- **Decisiones técnicas que explica:**
  1. **Sincronización incremental jerárquica (*offline-first*):** Todas las operaciones escriben primero en SQLite con estados `pending_create`, `pending_update` o `pending_delete`. Al recuperar la red, `SyncService` envía primero las materias nuevas antes que sus horarios, tareas, faltas o evaluaciones para respetar las llaves foráneas, y luego descarga deltas con `GET /api/sync?since=<timestamp>` sin sobrescribir cambios locales pendientes.
  2. **Confiabilidad de alertas de asistencia (I-7):** `showImmediateNotification` comprueba `areNotificationsEnabled()` en Android y devuelve `Future<bool>`, de modo que `_checkAndNotifyAbsenceAlerts` solo marca la alerta como enviada en `SharedPreferences` cuando la notificación realmente pudo mostrarse al estudiante.

### Nataly Marisol Santos Miam — Experiencia móvil, captura en clase e identidad visual
- **Archivos que demuestra:**
  - `app/lib/screens/home/home_screen.dart`
  - `app/lib/screens/tasks/task_form_dialog.dart`
  - `app/lib/screens/subjects/subject_detail_screen.dart`
  - `app/lib/screens/auth/login_screen.dart` y `register_screen.dart`
  - `docs/analisis-diseno.md` y `docs/manual-usuario.md`
- **Decisiones técnicas que explica:**
  1. **Captura rápida contextual en ≤ 3 toques:** Al abrir el formulario de nueva tarea durante una clase en curso, la app detecta automáticamente la materia actual según el horario y preselecciona como fecha de entrega la próxima sesión de esa materia, permitiendo adjuntar una foto del pizarrón con la cámara en segundos.
  2. **Adaptabilidad visual y estados claros:** Se eligió la identidad visual Vino UTM (`#7A1B29`) y Dorado (`#D49E35`) con alto contraste, etiquetas explícitas de `Pendiente sync` para evitar falsas confirmaciones sin red y contenedores `Wrap` en autenticación (**I-1**) para evitar desbordes en pantallas angostas o con fuente ampliada.

### Oscar Michel Matos May — Modelo de datos, aislamiento en servidor y seguridad
- **Archivos que demuestra:**
  - `backend/src/schema.sql`
  - `backend/src/routes/resource.js` y `backend/src/routes/uploads.js`
  - `backend/src/schemas.js` y `backend/src/middleware/auth.js`
  - `backend/test/smoke.js` y `backend/test/rate-limit.js`
  - `docs/datos-seguridad.md` y `docs/bitacora.md`
- **Decisiones técnicas que explica:**
  1. **Control de acceso en servidor y borrado lógico:** En lugar de ocultar botones en el cliente, todas las consultas SQL del backend filtran por `WHERE user_id = $1` extraído del token JWT firmado, y verifican que la materia pertenezca al usuario antes de insertar registros hijos (respondiendo `404` ante cualquier intento de acceso cruzado, comprobado con dos usuarios en `smoke.js`).
  2. **Protección de credenciales y archivos:** Las contraseñas se almacenan con `bcrypt` (costo 10), los endpoints de autenticación tienen límite de intentos (`express-rate-limit`), y las fotos se validan por tipo MIME (`JPG/PNG/WEBP/HEIC`) y tamaño (máx. 5 MB), guardándose con prefijo `<userId>-<uuid>` para que ningún otro usuario autenticado pueda descargarlas.

### Genaro Aurelio Antonio Pacheco — Ecosistema Web/Móvil, Widget Android, pruebas y empaquetado APK
- **Archivos que demuestra:**
  - `app/android/app/src/main/kotlin/mx/utm/app/HomeScreenWidgetProvider.kt`
  - `app/android/app/build.gradle.kts`
  - `app/test/` (10 archivos, 49 pruebas) y `web/src/` (18 pruebas)
  - `docs/pruebas.md`, `docs/web-vs-movil.md` y `docs/apk-firma.md`
- **Decisiones técnicas que explica:**
  1. **Complementariedad real entre Web y Móvil (Modalidad B):** La versión web en React está optimizada para la planeación inicial del cuatrimestre en pantalla grande, mientras que la app Flutter agrega capacidades exclusivas del dispositivo: widget nativo en pantalla de inicio, cámara, alarmas locales sin conexión y base SQLite local.
  2. **Firma de distribución segura fuera del repositorio:** Se configuró `signingConfigs.release` en Gradle leyendo `key.properties` (excluido por `.gitignore`) y una keystore RSA-2048 propia (`CN=MiSemestre UTM`) resguardada fuera del árbol de Git para generar un APK instalable con identidad propia (`mx.utm.app`).
