# Bitácora del equipo — MiSemestre UTM

> Registro de acuerdos, responsables y avances por versión del proyecto final.

---

## 2026-11-18 · Semana 1 · Análisis, propuesta y diseño

- **Asistentes:** Santiago Asahel Pech Ake, Nataly Marisol Santos Miam, Oscar Michel Matos May, Genaro Aurelio Antonio Pacheco.
- **Acuerdos:**
  - Elegir la **Modalidad B (Complemento de Desarrollo Web)** con el proyecto **MiSemestre UTM**.
  - Consultar con compañeros de 4.º cuatrimestre de la UTM sus principales problemas de organización académica (olvido de entregas, desconocimiento del conteo de faltas y cálculo de calificaciones).
  - Definir las 9 historias de usuario, el modelo entidad-relación con borrado lógico (`deleted_at`) para sincronización sin conexión y la identidad visual en tonos Vino UTM (`#7A1B29`) y Dorado (`#D49E35`).
- **Tareas asignadas:**
  - Santiago Asahel Pech Ake → Diseño del protocolo de sincronización (`GET /api/sync?since=`) y contrato de la API (`docs/api.md`).
  - Nataly Marisol Santos Miam → Mapa de navegación, bocetos de pantallas principales y guía visual (`docs/analisis-diseno.md`).
  - Oscar Michel Matos May → Esquema PostgreSQL (`backend/src/schema.sql`), reglas de aislamiento por usuario y política de seguridad (`docs/datos-seguridad.md`).
  - Genaro Aurelio Antonio Pacheco → Redacción de propuesta (`docs/propuesta.md`), estructura base de la web en React y configuración de Docker Compose.
- **Avance revisado:** Propuesta del proyecto, historias de usuario con criterios de aceptación, diagrama E-R y bocetos de interfaz.

---

## 2026-11-22 · Semana 2 · Versión 1.0.0 (MVP funcional)

- **Asistentes:** Santiago Asahel Pech Ake, Nataly Marisol Santos Miam, Oscar Michel Matos May, Genaro Aurelio Antonio Pacheco.
- **Avance:** API REST (autenticación JWT, CRUD por usuario, sincronización incremental y subida de fotos), app Android con base local SQLite para modo sin conexión y versión web funcional. Commit `9fad657`.
- **Acuerdos:**
  - Garantizar que toda operación en la app se guarde primero en SQLite con etiqueta `Pendiente sync` cuando no haya red y se sincronice en orden jerárquico (materias antes que horario, tareas, faltas y calificaciones).
  - Corregir el cálculo de faltas restantes para que nunca muestre valores negativos cuando se supera el límite (incidencia **I-6**).
- **Tareas realizadas:**
  - Santiago Asahel Pech Ake → `ApiService`, `DatabaseService`, `SyncService`, proveedores de estado en Flutter y corrección de **I-6**.
  - Nataly Marisol Santos Miam → Pantallas de Flutter: Inicio ("qué clase sigue"), Horario semanal, Tareas con foto de cámara, detalle de Materia, Faltas en 1 toque y Simulador.
  - Oscar Michel Matos May → Implementación del backend en Express + PostgreSQL, validación con Zod, control de acceso `WHERE user_id = $1` y protección de archivos en `/api/uploads`.
  - Genaro Aurelio Antonio Pacheco → Aplicación web en React + Vite integrada con la misma API y pruebas unitarias del calculador académico.

---

## 2026-11-23 · Semana 3 · Versión 1.1.0 (Experiencia móvil y confiabilidad)

- **Asistentes:** Santiago Asahel Pech Ake, Nataly Marisol Santos Miam, Oscar Michel Matos May, Genaro Aurelio Antonio Pacheco.
- **Avance:** Widget de pantalla de inicio en Android, recordatorios locales confiables (guía de batería y reprogramación al reiniciar el dispositivo), pantalla de ajustes y borrado de cuenta. Commit `f0ba7c3`.
- **Acuerdos:**
  - Incorporar el widget nativo de pantalla de inicio para consultar la clase siguiente y pendientes del día sin abrir la aplicación.
  - Agregar guía de configuración de batería para fabricantes con ahorro agresivo (Xiaomi, Huawei, Samsung) y corregir el selector de hora en el formulario de tareas (incidencia **I-5**).
- **Tareas realizadas:**
  - Santiago Asahel Pech Ake → `NotificationService` con alarmas exactas, receptor de arranque para reprogramar recordatorios y corrección de **I-5**.
  - Nataly Marisol Santos Miam → Pantalla de guía de batería, pantalla de Ajustes, selector de servidor y diálogo de confirmación para borrar cuenta (`BORRAR`).
  - Oscar Michel Matos May → Endpoint `DELETE /api/me` con borrado en cascada y eliminación de fotos del usuario, además del script de datos realistas `npm run seed:demo`.
  - Genaro Aurelio Antonio Pacheco → Proveedor nativo del widget en Kotlin (`HomeScreenWidgetProvider.kt`), servicio `HomeWidgetService` y pruebas de widgets/ajustes.

---

## 2026-11-23 · Semana 3 · Versión 1.2.0 (Pruebas, firma de APK y entrega final)

- **Asistentes:** Santiago Asahel Pech Ake, Nataly Marisol Santos Miam, Oscar Michel Matos May, Genaro Aurelio Antonio Pacheco.
- **Avance:**
  - Ícono adaptativo propio y APK de distribución firmado con clave de release del equipo (`CN=MiSemestre UTM`, resguardada fuera del repositorio).
  - Pruebas automatizadas de validación de formularios (datos inválidos), corrección de desborde visual en login/registro (**I-1**) y corrección del reintento de alerta de faltas cuando el permiso de notificaciones se concede después (**I-7**).
  - Sincronización de `package-lock.json` en web (**I-2**) y validación completa: App **49/49** pruebas (`flutter analyze` sin observaciones), Web **18/18** pruebas y Backend **13/13** pruebas en Docker.
  - Documentación completa de los 9 entregables, capturas y videos de evidencia en `docs/evidencias/` y presentación ejecutiva (`presentacion/MiSemestre-UTM-pitch.pptx`).
- **Tareas realizadas:**
  - Santiago Asahel Pech Ake → Corrección de la incidencia **I-7** en `NotificationService` y `AbsenceProvider`, verificación de sincronización y revisión de integración.
  - Nataly Marisol Santos Miam → Corrección responsiva con `Wrap` en login/registro (**I-1**), generación de ícono propio (**I-4**) y manual de usuario (`docs/manual-usuario.md`).
  - Oscar Michel Matos May → Pruebas automatizadas del backend (`smoke.js` con aislamiento entre dos usuarios y `rate-limit.js`), documentación de arquitectura de datos y seguridad (`docs/datos-seguridad.md`).
  - Genaro Aurelio Antonio Pacheco → Configuración de firma release (**I-3**), compilación y verificación con `apksigner`, matriz de pruebas e incidencias (`docs/pruebas.md`), grabación de evidencias y presentación pitch.
