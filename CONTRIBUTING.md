# Reglas de colaboración

## Ramas

- `main`: siempre compila y pasa las pruebas. **No se sube directo**: todo entra por Pull Request.
- Una rama por funcionalidad o corrección, con nombre descriptivo:
  - `feat/app-foto-tarea`, `feat/web-simulador`, `fix/app-selector-hora`, `docs/pruebas`, `entrega/v1.2.0`.

## Commits

- Pequeños y en español, en imperativo: `Agrega alerta al llegar al límite de faltas`.
- Un commit = un cambio con sentido. No mezclar formato con lógica.
- Cada quien sube su propio trabajo con su cuenta de GitHub (la participación se revisa por autor).

## Pull Requests

1. Antes de abrir el PR:
   - App: `flutter analyze` sin problemas y `flutter test` en verde.
   - Web: `npm test` y `npm run build`.
   - Backend: con la API corriendo, `npm test`.
2. Descripción: qué cambia, cómo se probó y capturas si hay cambios de interfaz.
3. **Al menos un compañero revisa** y aprueba antes de integrar.
4. Si hay conflictos, quien abrió el PR los resuelve y vuelve a probar el flujo afectado.

## Tareas

- Cada tarea es un *Issue* con responsable y etiqueta (`app`, `web`, `backend`, `docs`, `pruebas`).
- El PR que la resuelve la menciona: `Cierra #12`.
- Acuerdos de las reuniones en [docs/bitacora.md](docs/bitacora.md).

## Lo que nunca se sube

`.env`, `key.properties`, `*.jks`, `*.keystore`, `*.apk`, contraseñas, tokens, carpetas `build/` y `node_modules/`
(ya están en `.gitignore`). Si algo se sube por error: avisar al equipo y **cambiar** el secreto, no solo borrarlo.

## Cambios a la API

El backend es dueño de `docs/api.md`. Si la app o la web necesitan algo nuevo, se pide en
`docs/pendientes-frontend.md` y se actualiza el contrato en el mismo PR que lo implementa.
