# Pruebas y validación — MiSemestre UTM v1.2.0

> Entregable 6: matriz de validación, pruebas automatizadas, incidencias corregidas y evidencias.
> **Estado:** ✅ comprobado · 🔁 automatizado · 📱 comprobado en emulador Android 15 (Pixel 6) con el APK firmado · ✏️ pendiente en teléfono físico.

## 1. Pruebas automatizadas

| Conjunto | Comando | Resultado (2026-11-23) |
|---|---|---|
| App · análisis estático | `cd app; flutter analyze` | ✅ *No issues found* |
| App · unitarias y de widgets (10 archivos) | `cd app; flutter test` | ✅ **49 de 49** pasan |
| Web · unitarias | `cd web; npm test` | ✅ **18 de 18** pasan |
| Web · compilación | `cd web; npm run build` | ✅ compila |
| Backend · humo + aislamiento + límite de intentos | `docker compose up -d` y luego `cd backend; npm test` con la API corriendo | ✅ 13 de 13 casos; salida en `evidencias/2026-11-23_backend-tests.txt` |
| APK de distribución firmado | `cd app; flutter build apk --release` + `apksigner verify` | ✅ ver sección 5 |

Qué cubren las pruebas de la app:

| Archivo | Cubre |
|---|---|
| `form_validation_test.dart` | **Datos inválidos**: login vacío, correo mal escrito, contraseña corta, confirmación distinta, nombre vacío |
| `absences_and_grades_test.dart` | Simulador de calificación, faltas justificadas, umbral de alerta, migración de base local, falta duplicada |
| `new_features_test.dart` | Agrupación de tareas por fecha, "qué clase sigue", fechas de recordatorio, orden de sincronización |
| `offline_sync_and_update_test.dart` | **Error de red** → `ApiException` 0; el sync no pisa cambios locales pendientes |
| `photo_upload_and_alerts_test.dart` | Tipo MIME de la foto, subida diferida de la foto, borrar falta sin notificar |
| `settings_and_features_test.dart` | Ajustes, borrar cuenta (con y sin conexión), guía de batería, repetir clase, captura rápida, abrir tarea desde notificación |
| `demo_adjustments_test.dart` | Etiqueta **Pendiente sync**, faltas restantes nunca negativas |
| `widget_smoke_test.dart`, `widget_test.dart`, `models_test.dart` | Todas las pantallas construyen sin errores; modelos cumplen el contrato de la API |

Qué cubre la prueba del backend (`backend/test/smoke.js`): registro, login incorrecto (401), materia, horario,
tarea con id del cliente, subir y leer foto, y **aislamiento con dos usuarios** (leer/editar/borrar/ver foto ajena → 404).
`rate-limit.js` comprueba el 429 tras 10 logins fallidos.

## 2. Matriz de validación (sección 10 de los lineamientos)

| Prueba | Qué comprobamos | Resultado esperado | Cómo | Estado |
|---|---|---|---|---|
| Instalación | El APK se instala y abre en Android | Inicio correcto, sin cierre | Emulador Android 15 · `adb install` | 📱 ✅ (`00`, `01`) / ✏️ teléfono |
| Flujo principal | Iniciar sesión → tarea con foto de la cámara → verla en Tareas y en la web | Datos se guardan y consultan | Emulador + web | 📱 ✅ (`flujo-principal.mp4`, `06`, `07`, `14`) |
| Validaciones | Campos vacíos, correo inválido, contraseña corta, % de evaluaciones ≠ 100, falta duplicada | Mensajes claros, sin datos corruptos | 🔁 `form_validation_test`, `absences_and_grades_test` (g) | ✅ |
| Persistencia | Cerrar la app (y reiniciar el teléfono) y volver a abrir | Registros y recordatorios permanecen | Forzar cierre en emulador | 📱 ✅ (`13`) / ✏️ reinicio del teléfono |
| Seguridad | Usuario B intenta leer/editar datos y fotos de A | 404, sin acceso | 🔁 `backend/test/smoke.js` | ✅ |
| Conectividad | Modo avión durante una operación | Queda **Pendiente sync**; sin falsa confirmación; se envía al volver la red | 🔁 `offline_sync…` + modo avión en emulador | ✅ auto · 📱 ✅ (`sin-conexion-pendiente-sync.mp4`, `08`, `09`) |
| Función móvil | Foto con cámara, recordatorio sin internet, alerta de faltas, widget | Llegan y abren la tarea | Emulador | 📱 ✅ cámara y alerta de faltas (`06`, `11`, `12`) / ✏️ recordatorio y widget |
| Integración web | Crear en la web → sincronizar en la app, y al revés; borrar en la web | Mismos datos en ambos | Emulador + web | 📱 ✅ app → web (`14`) / ✏️ web → app |

### Validación mínima exigida

| Caso | Dónde se demuestra |
|---|---|
| Caso exitoso | Flujo principal en la demo (crear tarea con foto y verla en la web) |
| Caso con datos inválidos | Login con correo `ana-sin-arroba` → "Ingresa un correo válido" (prueba automatizada + demo) |
| Control de acceso | Segundo usuario no ve los datos del primero (`smoke.js`, demo con dos cuentas) |
| Error de conexión | Modo avión → tarea con **Pendiente sync**; borrar cuenta sin red muestra error y no borra nada |

## 3. Registro de incidencias

| # | Pasos para reproducir | Esperado | Obtenido | Responsable | Corrección | Evidencia |
|---|---|---|---|---|---|---|
| I-1 | Registro en un teléfono angosto o con letra del sistema agrandada | Todo el texto visible | La fila "¿Ya tienes una cuenta? Inicia sesión" se desborda 129 px (franja amarilla) | ✏️ | `Row` → `Wrap` en registro y login | `form_validation_test.dart` pasa sin errores de layout |
| I-2 | `cd web; npm ci` en una PC limpia | Instala dependencias | Falla: `package-lock.json` desincronizado (faltan `@emnapi/*`) | ✏️ | Lockfile regenerado con `npm install` | `npm ci`, `npm test` 18/18 y `npm run build` correctos |
| I-3 | Compilar release | APK firmado con clave del proyecto | Firmado con la clave de **debug** | ✏️ | `signingConfigs.release` + `key.properties` fuera de Git | `apksigner` muestra `CN=MiSemestre UTM` |
| I-4 | Instalar el APK | Ícono propio | Ícono por defecto de Flutter | ✏️ | Ícono propio + `flutter_launcher_icons` (adaptativo) | Captura del cajón de apps ✏️ |
| I-5 | Elegir hora de entrega en el formulario de tarea | Se guarda la hora elegida | El selector no respetaba la hora elegida (desarrollo de v1.1.0) | ✏️ | Corregido en v1.1.0 | `settings_and_features_test` grupo 5 |
| I-6 | Registrar más faltas que el límite | "Restantes: 0" | Mostraba número negativo (desarrollo de v1.0.0) | ✏️ | Corregido en v1.0.0 | `demo_adjustments_test` caso 2 |
| I-7 | Negar el permiso de notificaciones al abrir la app → registrar la falta que deja 1 restante → conceder el permiso → registrar otra | La alerta llega cuando ya hay permiso | No llega: la app marca la alerta como "enviada" aunque Android la bloqueó | ✏️ | **Abierta.** Propuesta: guardar la marca solo si el permiso está concedido (`absence_provider.dart`, `_checkAndNotifyAbsenceAlerts`) | Encontrado en emulador; con permiso concedido la alerta sí llega (`12`) |

> ✏️ Agregar aquí cada defecto que encuentren al probar en el teléfono, con el mismo formato.

## 4. Evidencias

En `docs/evidencias/`, tomadas el 2026-11-23 con el **APK firmado v1.2.0** instalado en un emulador
Android 15 (Pixel 6, `system-images;android-35;google_apis;x86_64`), API en Docker y web en `localhost:5173`:

| Archivo | Qué muestra |
|---|---|
| `2026-11-23_00-icono-instalado.png` | App instalada con su ícono propio |
| `2026-11-23_01-inicio-login.png`, `02-servidor-conectado.png` | Primera pantalla y conexión con la API |
| `2026-11-23_03-validacion-correo.png` | Dato inválido: "Ingresa un correo válido" |
| `2026-11-23_04-…`, `05-inicio-hoy.png` | Guía de batería e inicio con datos sincronizados |
| `2026-11-23_06-tarea-con-foto.png`, `07-lista-tareas.png` | Tarea con foto de la cámara |
| `2026-11-23_flujo-principal.mp4` | Video: validación, inicio de sesión y tarea con foto |
| `2026-11-23_sin-conexion-pendiente-sync.mp4`, `08`, `09` | Modo avión → **Pendiente sync** → al volver la red se sincroniza |
| `2026-11-23_10-simulador-calificacion.png` | Simulador: necesita 8.75 |
| `2026-11-23_11-alerta-faltas.png`, `12-notificacion-faltas.png` | Notificación "Te quedan 1 falta(s)" |
| `2026-11-23_13-persistencia-tras-reabrir.png` | Datos siguen tras forzar el cierre |
| `2026-11-23_14-web-ve-tarea-del-telefono.jpg` | La web muestra la tarea y la foto creadas en el teléfono |
| `2026-11-23_backend-tests.txt` | Salida de `npm test` del backend con Docker |

Pendiente en teléfono físico ✏️: instalar desde el archivo, recordatorio a la hora programada sin internet,
widget en pantalla de inicio, reinicio del teléfono y crear en la web → ver en la app.

## 5. APK entregado

- Archivo: `MiSemestre-UTM-v1.2.0.apk`
- Versión: 1.2.0 (código 3) · paquete `mx.utm.app`
- Firma: ver la salida de `apksigner` abajo.

```text
$ apksigner verify --print-certs MiSemestre-UTM-v1.2.0.apk
Signer #1 certificate DN: CN=MiSemestre UTM, OU=Desarrollo Movil, O=Equipo MiSemestre, L=Merida, ST=Yucatan, C=MX
Signer #1 certificate SHA-256 digest: ad702fd0dcd8f3d92a5feff51c8228d964013e939d396aa7b1101cde379bf5d0

$ aapt2 dump badging MiSemestre-UTM-v1.2.0.apk
package: name='mx.utm.app' versionCode='3' versionName='1.2.0' compileSdkVersion='37'
targetSdkVersion:'36'
application-label:'MiSemestre UTM'
```

Tamaño: 59.1 MB (APK universal para todas las arquitecturas).
