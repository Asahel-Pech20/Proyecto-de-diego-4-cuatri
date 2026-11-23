# MiSemestre UTM — reglas para Claude (backend)

Proyecto: agenda académica para estudiantes de la UTM. Ver `README.md`.

## Reparto de trabajo
- **Claude** trabaja SOLO en `backend/`, `docs/api.md`, `docker-compose.yml` y este archivo.
- **Gemini (Antigravity)** trabaja en `app/` (Flutter, Android) y `web/` (React). No tocar esas carpetas.
- `docs/api.md` es el contrato entre backend y frontend. Si cambia una ruta o un campo, actualizar `docs/api.md` en el mismo cambio y anotarlo en la sección "Cambios" al final.

## Stack backend
- Node.js 24 + Express 5 (ESM), PostgreSQL 16 con `pg` (SQL directo, sin ORM).
- Auth: bcryptjs + JWT (Bearer). Validación con zod.
- Esquema en `backend/src/schema.sql` (idempotente, se aplica al arrancar).
- JSON en camelCase hacia fuera; columnas en snake_case en la base.

## Comandos
- `docker compose up -d` — levanta Postgres.
- `cd backend && npm install && npm run dev` — API en http://localhost:3000.
- `cd backend && npm test` — prueba de humo contra la API corriendo.
