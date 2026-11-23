# MiSemestre UTM — reglas para Gemini (frontend)

Proyecto: agenda académica para estudiantes de la UTM. Ver `README.md`.

## Reparto de trabajo
- **Gemini** trabaja SOLO en `app/` (Flutter, Android) y `web/` (React).
- **Claude** se encarga de `backend/` y `docs/api.md`. **No modifiques esos archivos.**
- Toda la comunicación con el servidor sigue `docs/api.md`. Si necesitas una ruta o un campo que no existe, no lo inventes: anótalo en `docs/pendientes-frontend.md` para que Claude lo agregue.

## App Android — `app/` (Flutter)
- Crear con `flutter create --org mx.utm --platforms android app`.
- Desde el emulador de Android, el backend está en `http://10.0.2.2:3000`; desde un teléfono físico, en la IP de la computadora en la red local (ej. `http://192.168.1.50:3000`). Dejar la URL base configurable.
- Guardar el token JWT con `flutter_secure_storage`.
- Recordatorios: notificaciones LOCALES con `flutter_local_notifications` + `timezone`, programadas en el teléfono a partir de `dueAt` y `reminders` (minutos antes) de cada tarea. Funcionan sin internet.
- Sin conexión: guardar datos en una base local (`sqflite` o `drift`) y sincronizar con `GET /api/sync?since=...` (ver `docs/api.md`). Generar los `id` (UUID) en el teléfono para poder crear sin conexión.
- Cámara/galería: `image_picker`; subir con `POST /api/uploads` y guardar el `url` devuelto en `photoUrl` de la tarea. Para mostrar la foto, mandar el header `Authorization`.
- Pantallas: login/registro, inicio ("¿qué clase sigue?" + pendientes de hoy), horario semanal, materias, tareas/exámenes (captura rápida en 3 toques), faltas, calificaciones con simulador (`GET /api/subjects/:id/summary`), ajustes (borrar cuenta).

## Web — `web/` (React)
- Crear con `npm create vite@latest web -- --template react`.
- Versión sencilla para consultar y editar: login, horario, tareas, materias, faltas y calificaciones.
- URL base del API en variable `VITE_API_URL` (por defecto `http://localhost:3000`).
