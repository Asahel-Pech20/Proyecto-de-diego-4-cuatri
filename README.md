# MiSemestre UTM

Agenda académica del estudiante: horario, tareas, exámenes, faltas y calificaciones, con recordatorios.
Proyecto final de Desarrollo de Aplicaciones Móviles.

## Equipo

- Santiago Asahel Pech Ake
- Nataly Marisol Santos Miam
- Oscar Michel Matos May
- Genaro Aurelio Antonio Pacheco

## Estructura

| Carpeta | Qué es |
|---|---|
| `backend/` | API REST (Node.js + Express + PostgreSQL) |
| `app/` | App Android (Flutter) |
| `web/` | Versión web (React + Vite) |
| `docs/api.md` | Contrato de la API entre el backend y los frontends |
| `docs/manual-usuario.md` | Manual de usuario de la app |
| `docs/cuentas-prueba.md` | Cuentas de prueba y cuenta de demo |

## Descargar la app

El APK instalable está en la sección [Releases](https://github.com/Asahel-Pech20/Proyecto-de-diego-4-cuatri/releases).
Cómo instalarla y usarla: [docs/manual-usuario.md](docs/manual-usuario.md).

## Arrancar el backend
```powershell
docker compose up -d
cd backend
copy .env.example .env
npm install
npm run dev
```
La API queda en http://localhost:3000 (`GET /api/health` para comprobar).
Postgres corre en Docker en el puerto **5440**.

Pruebas (con la API corriendo): `npm test` (prueba de humo, aislamiento entre usuarios y límite de intentos de login).
Cuenta de demo con datos realistas: `npm run seed:demo` (ver `docs/cuentas-prueba.md`).

## Web
```powershell
cd web
npm install
npm run dev
```
Abre http://localhost:5173. Pruebas: `npm test`.
