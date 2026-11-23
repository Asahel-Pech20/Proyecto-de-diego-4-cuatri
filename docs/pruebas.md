# Pruebas y validación — MiSemestre UTM v1.2.0

> Entregable 6: matriz de validación, pruebas automatizadas, incidencias corregidas y evidencias.
> **Estado:** ✅ comprobado · 🔁 automatizado · ✏️ pendiente de ejecutar en teléfono real y anotar evidencia.

## 1. Pruebas automatizadas

| Conjunto | Comando | Resultado (2026-11-23) |
|---|---|---|
| App · análisis estático | `cd app; flutter analyze` | ✅ *No issues found* |
| App · unitarias y de widgets (10 archivos) | `cd app; flutter test` | ✅ **49 de 49** pasan |
| Web · unitarias | `cd web; npm test` | ✅ **18 de 18** pasan |
| Web · compilación | `cd web; npm run build` | ✅ compila |
| Backend · humo + aislamiento + límite de intentos | `cd backend; npm test` (con Docker y la API corriendo) | ✏️ correr en la PC con Docker y anotar |
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
| Instalación | El APK se instala y abre en Android | Inicio correcto, sin cierre | Teléfono real | ✏️ |
| Flujo principal | Crear materia → horario → tarea con foto → verla en Tareas y en la web | Datos se guardan y consultan | Teléfono + web | ✏️ / 🔁 parcial |
| Validaciones | Campos vacíos, correo inválido, contraseña corta, % de evaluaciones ≠ 100, falta duplicada | Mensajes claros, sin datos corruptos | 🔁 `form_validation_test`, `absences_and_grades_test` (g) | ✅ |
| Persistencia | Cerrar la app (y reiniciar el teléfono) y volver a abrir | Registros y recordatorios permanecen | Teléfono real | ✏️ / 🔁 migración SQLite |
| Seguridad | Usuario B intenta leer/editar datos y fotos de A | 404, sin acceso | 🔁 `backend/test/smoke.js` | ✏️ correr |
| Conectividad | Modo avión durante una operación | Queda **Pendiente sync**; sin falsa confirmación; se envía al volver la red | 🔁 `offline_sync…`, `demo_adjustments…` + teléfono | ✅ auto / ✏️ teléfono |
| Función móvil | Foto con cámara, recordatorio sin internet, alerta de faltas, widget | Llegan y abren la tarea | Teléfono real | ✏️ |
| Integración web | Crear en la web → sincronizar en la app, y al revés; borrar en la web | Mismos datos en ambos | Teléfono + web | ✏️ |

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

> ✏️ Agregar aquí cada defecto que encuentren al probar en el teléfono, con el mismo formato.

## 4. Evidencias

Guardar capturas o video en `docs/evidencias/` con nombre `AAAA-MM-DD_prueba.png`:

- ✏️ `instalacion.png`: app instalada con su ícono.
- ✏️ `flujo-principal.mp4`: tarea con foto creada en la app y vista en la web.
- ✏️ `validacion-correo.png`, `pendiente-sync.png`, `recordatorio.png`, `alerta-faltas.png`, `widget.png`.
- ✏️ `backend-tests.png`: salida de `npm test` del backend.

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
