# MiSemestre UTM

Agenda académica del estudiante: horario, tareas, exámenes, faltas y calificaciones, con recordatorios.

| Carpeta | Qué es | Quién la trabaja |
|---|---|---|
| `backend/` | API REST (Node + Express + PostgreSQL) | Claude |
| `app/` | App Android (Flutter) | Gemini |
| `web/` | Versión web (React) | Gemini |
| `docs/api.md` | Contrato de la API | Claude (Gemini solo lo lee) |

## Arrancar el backend
```powershell
docker compose up -d
cd backend
copy .env.example .env
npm install
npm run dev
```
La API queda en http://localhost:3000 (`GET /api/health` para comprobar).
Postgres corre en Docker en el puerto **5440** (los puertos 5432/5433 los usa otro proyecto).
Prueba de humo (con la API corriendo): `npm test`.
Cuenta de demo con datos realistas: `npm run seed:demo` (ver `docs/cuentas-prueba.md`).
