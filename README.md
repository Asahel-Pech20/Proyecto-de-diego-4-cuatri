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
| `presentacion/` | Presentación de venta del proyecto (pitch para inversionistas) |

## Entregables del proyecto final

| # | Entregable | Dónde |
|---|---|---|
| 1 | Propuesta | [docs/propuesta.md](docs/propuesta.md) |
| 2 | Análisis y diseño (historias, mapa de navegación, bocetos, guía visual) | [docs/analisis-diseno.md](docs/analisis-diseno.md) |
| 3 | Código fuente | `app/`, `web/`, `backend/` |
| 4 | Repositorio y colaboración | [CONTRIBUTING.md](CONTRIBUTING.md) · [docs/bitacora.md](docs/bitacora.md) |
| 5 | Datos y seguridad | [docs/datos-seguridad.md](docs/datos-seguridad.md) |
| 6 | Pruebas e incidencias | [docs/pruebas.md](docs/pruebas.md) |
| 7 | APK firmado | *Releases* · cómo generarlo: [docs/apk-firma.md](docs/apk-firma.md) |
| 8 | Demostración | Flujo en [docs/analisis-diseno.md#7-flujo-que-se-demostrará](docs/analisis-diseno.md) · [presentacion/](presentacion/) |
| 9 | Complemento web | [docs/web-vs-movil.md](docs/web-vs-movil.md) |

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

## App (Flutter)
Requisitos: Flutter 3.47+ (Dart 3.13) y Android SDK.
```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run            # en un teléfono o emulador conectado
```
En el teléfono, toca **Configurar servidor** en el inicio de sesión y escribe `http://<IP-de-la-PC>:3000`
(misma red Wi-Fi). En el emulador la dirección por defecto `http://10.0.2.2:3000` ya funciona.

APK de distribución firmado: ver [docs/apk-firma.md](docs/apk-firma.md).
