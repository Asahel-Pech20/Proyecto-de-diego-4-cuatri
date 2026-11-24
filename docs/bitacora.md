# Bitácora del equipo

> Acuerdos y tareas por semana. ✏️ Completar con fechas y acuerdos reales de cada reunión:
> el docente revisa avances semanales y la participación de cada integrante.

Formato:

```
## AAAA-MM-DD · Semana N
Asistentes: ...
Acuerdos:
- ...
Tareas (responsable → entrega):
- Nombre → tarea (Issue #)
Avance mostrado al docente: ...
```

---

## 2026-11-22 · Versión 1.0.0

Avance: API REST (auth, CRUD, sincronización, fotos), app Android con modo sin conexión y versión web.
Commit `9fad657`.

✏️ Asistentes / acuerdos / quién hizo qué.

## 2026-11-23 · Versión 1.1.0

Avance: widget de pantalla de inicio, recordatorios confiables (guía de batería, reprogramación al
reiniciar), ajustes y borrado de cuenta. Commit `f0ba7c3`.

✏️ Asistentes / acuerdos / quién hizo qué.

## 2026-11-23 · Versión 1.2.0 (entrega)

Avance:
- Ícono propio de la app y APK de distribución firmado con clave del proyecto (fuera del repo).
- Pruebas de validación de formularios (datos inválidos) y corrección de desbordes en login/registro.
- Lockfile de la web sincronizado (`npm ci` fallaba).
- Documentación de entrega: propuesta, análisis y diseño, web vs. móvil, datos y seguridad, pruebas, APK y presentación.

Pendiente del equipo:
- ✅ APK probado en emulador Android 15: capturas y videos en `docs/evidencias/`.
- ✅ `npm test` del backend con Docker: 13 de 13 casos (ver `docs/pruebas.md`).
- ✏️ Repetir en un teléfono físico: recordatorio sin internet, widget y reinicio.
- ✏️ Corregir I-7 (alerta de faltas cuando se negó el permiso de notificaciones).
- ✏️ Cada integrante sube su parte con su cuenta: ver [participacion.md](participacion.md).
