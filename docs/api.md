# API de MiSemestre UTM — contrato

> Lo mantiene el backend. La app y la web **solo lo leen**. Si falta algo, pídelo en `docs/pendientes-frontend.md`.

- **URL base:** `http://localhost:3000` (web) · `http://10.0.2.2:3000` (emulador Android) · `http://<IP-de-la-PC>:3000` (teléfono físico en la misma Wi-Fi).
- **Formato:** JSON en camelCase. Fechas-hora en ISO 8601 con zona (`2026-11-20T14:00:00.000Z`). Fechas solas `YYYY-MM-DD`. Horas `HH:MM`.
- **Autenticación:** todas las rutas excepto `/api/health` y `/api/auth/*` requieren el header
  `Authorization: Bearer <token>`. El token dura 30 días.
- **IDs:** UUID. En los `POST` el cliente **puede** mandar su propio `id` (útil para crear sin conexión). Si ese id ya existe → `409`.

## Errores
Siempre `{ "error": "mensaje" }` con el código HTTP:

| Código | Cuándo |
|---|---|
| 400 | Datos inválidos. Incluye `details` con `fieldErrors` por campo. |
| 401 | Sin token, token inválido, o login incorrecto. |
| 404 | No existe o no es del usuario. |
| 409 | Correo ya registrado, o `id` repetido. |
| 429 | Demasiados intentos: 10 logins fallidos en 15 min, o 30 registros en 1 h, desde la misma IP. Mostrar el `error` tal cual y no reintentar en automático. |
| 500 | Error del servidor. |

---

## Auth

### `POST /api/auth/register`
```json
{ "name": "Ana López", "email": "ana@utm.edu.mx", "password": "mínimo 8 caracteres" }
```
→ `201` `{ "token": "...", "user": User }`

### `POST /api/auth/login`
```json
{ "email": "ana@utm.edu.mx", "password": "..." }
```
→ `200` `{ "token": "...", "user": User }`

### `GET /api/me` → `User`
### `DELETE /api/me` → `204`. Borra la cuenta y **toda** su información (materias, tareas, fotos…). No se puede deshacer.

```ts
User = { id, name, email, createdAt }
```

---

## Recursos (mismo patrón para todos)

| Recurso | Ruta |
|---|---|
| Materias | `/api/subjects` |
| Horario | `/api/schedules` |
| Tareas y exámenes | `/api/tasks` |
| Faltas | `/api/absences` |
| Calificaciones | `/api/grades` |

| Método | Ruta | Respuesta |
|---|---|---|
| `GET` | `/api/<recurso>` | `200` lista (sin borrados). Filtro opcional `?subjectId=<uuid>` (no aplica a materias). |
| `GET` | `/api/<recurso>/:id` | `200` objeto |
| `POST` | `/api/<recurso>` | `201` objeto creado |
| `PATCH` | `/api/<recurso>/:id` | `200` objeto actualizado (manda solo los campos que cambian) |
| `DELETE` | `/api/<recurso>/:id` | `204` |

Todos los objetos traen además: `id`, `createdAt`, `updatedAt`, `deletedAt` (null si vigente).

Borrar una **materia** borra también su horario, tareas, faltas y calificaciones.

### Materia
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `name` | string ≤100 | sí | |
| `teacher` | string \| null | no | |
| `color` | `#RRGGBB` \| null | no | |
| `maxAbsences` | entero ≥0 \| null | no | Límite de faltas que puso el profesor. null = sin límite. |
| `passingGrade` | número | no | Por defecto `8`. |
| `gradeScale` | número | no | Calificación máxima. Por defecto `10`. |

### Horario (una fila por clase en la semana)
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `subjectId` | uuid | sí | |
| `dayOfWeek` | 1–7 | sí | 1 = lunes … 7 = domingo |
| `startTime` | `HH:MM` | sí | |
| `endTime` | `HH:MM` | sí | |
| `room` | string \| null | no | Salón |

### Tarea / examen
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `subjectId` | uuid | sí | |
| `kind` | `"task"` \| `"exam"` | no | Por defecto `"task"` |
| `title` | string ≤200 | sí | |
| `description` | string \| null | no | |
| `dueAt` | ISO datetime | sí | Fecha y hora de entrega / examen |
| `done` | boolean | no | Por defecto `false` |
| `photoUrl` | string \| null | no | El `url` devuelto por `POST /api/uploads` |
| `reminders` | entero[] | no | Minutos antes de `dueAt` para avisar. Por defecto `[1440, 120]` (1 día y 2 h). Máx. 10. |

> Las notificaciones las programa **el teléfono** (notificaciones locales) usando `dueAt` y `reminders`. El servidor no manda push.

### Falta
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `subjectId` | uuid | sí | |
| `date` | `YYYY-MM-DD` | sí | |
| `justified` | boolean | no | Las justificadas no cuentan para el límite |
| `note` | string \| null | no | |

### Calificación (una fila por evaluación del curso)
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `subjectId` | uuid | sí | |
| `name` | string | sí | Ej. "Parcial 1", "Proyecto final" |
| `weight` | 0–100 | sí | Porcentaje que vale en la calificación final |
| `score` | número \| null | no | Calificación obtenida (en la escala de la materia). **null = todavía no se presenta** (el simulador la usa como pendiente). |

---

## Resumen de una materia (faltas + simulador)

### `GET /api/subjects/:id/summary`
```json
{
  "absences": {
    "count": 4, "justified": 0, "max": 5, "remaining": 1,
    "atRisk": true, "exceeded": false
  },
  "grades": {
    "gradeScale": 10, "passingGrade": 8,
    "gradedWeight": 60, "pendingWeight": 40, "totalWeight": 100,
    "accumulated": 4.5,
    "currentAverage": 7.5,
    "neededOnPending": 8.75,
    "status": "possible"
  }
}
```
- `atRisk`: quedan 1 o menos faltas (o ≤20 % del límite). Mostrar aviso.
- `accumulated`: puntos ya asegurados sobre la calificación final.
- `currentAverage`: promedio de lo ya evaluado.
- `neededOnPending`: lo que necesita sacar (en promedio) en lo que falta para aprobar.
- `status`: `"possible"` · `"secured"` (ya aprobó aunque saque 0) · `"impossible"` (necesitaría más que la escala) · `"approved"` / `"failed"` (ya no hay pendientes) · `"no-data"`.

> En la app, el simulador "¿cuánto necesito en el final?" puede calcularse también en local con la misma fórmula:
> `neededOnPending = (passingGrade − Σ(score·weight/100)) · 100 / Σ(weight pendientes)`.

---

## Fotos

### `POST /api/uploads`
`multipart/form-data` con el campo **`photo`** (JPG, PNG, WEBP o HEIC, máx. 5 MB).
La parte `photo` **debe llevar su Content-Type de imagen** (`image/jpeg`, `image/png`, `image/webp` o `image/heic`); si llega como `application/octet-stream` la API responde `400`.
En Flutter: `http.MultipartFile.fromPath('photo', path, contentType: MediaType('image', 'jpeg'))` (paquete `http_parser`; usa el subtipo según la extensión del archivo).
→ `201` `{ "url": "/api/uploads/<archivo>" }` → guardarlo en `photoUrl` de la tarea.

### `GET /api/uploads/<archivo>`
Devuelve la imagen. **Requiere** el header `Authorization` (solo el dueño la ve).
En Flutter: `Image.network(base + url, headers: {'Authorization': 'Bearer $token'})`.

---

## Sincronización (modo sin conexión)

### `GET /api/sync` y `GET /api/sync?since=<serverTime anterior>`
```json
{
  "serverTime": "2026-11-19T20:15:00.123Z",
  "subjects": [...], "schedules": [...], "tasks": [...], "absences": [...], "grades": [...]
}
```
Flujo recomendado en la app:
1. Primera vez (o después del login): `GET /api/sync` → guardar todo en la base local y guardar `serverTime`.
2. Cambios hechos sin conexión: guardarlos en una cola local. Al volver la conexión, enviarlos en orden (`POST` con el `id` generado en el teléfono, `PATCH`, `DELETE`). Un `409` en un `POST` significa que ya se había enviado: ignorarlo.
3. Luego `GET /api/sync?since=<serverTime guardado>` → aplicar los cambios; si un registro trae `deletedAt` distinto de null, borrarlo localmente. Guardar el nuevo `serverTime`.

---

## Salud
`GET /api/health` → `{ "ok": true }` (sin token).

---

## Cambios
- 2026-11-19 — Versión inicial.
- 2026-11-19 — Fotos: aclarado que la parte `photo` debe enviarse con Content-Type de imagen.
- 2026-11-23 — Auth: límite de intentos (`429`) en `/api/auth/login` y `/api/auth/register`.
