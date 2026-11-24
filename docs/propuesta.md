# Propuesta del proyecto — MiSemestre UTM

> Entregable 1 del proyecto final. Formato de la sección 4 del documento de lineamientos.

| Campo | Información |
|---|---|
| **Nombre del proyecto** | MiSemestre UTM |
| **Equipo** | Santiago Asahel Pech Ake · Nataly Marisol Santos Miam · Oscar Michel Matos May · Genaro Aurelio Antonio Pacheco (responsabilidades en la tabla de abajo) |
| **Modalidad** | **B. Complemento de Desarrollo Web.** Existe una versión web (React) y la app Android (Flutter) agrega lo que solo puede hacer el teléfono. |
| **Problema** | El estudiante lleva su semestre repartido entre fotos en la galería, grupos de WhatsApp, notas en papel y su memoria: no sabe con certeza cuántas faltas lleva por materia, qué calificación necesita para aprobar ni cuándo vence cada entrega. Se entera tarde de que perdió el derecho a examen o de que una tarea era "para hoy". Hoy se resuelve con capturas de pantalla, alarmas sueltas del reloj y preguntándole al compañero. |
| **Usuario objetivo** | Estudiante universitario (UTM) que consulta su día **en el pasillo, en el camión o en el salón**, muchas veces sin datos móviles, y que necesita registrar algo en segundos cuando el profesor lo dice. |
| **Solución propuesta** | Una agenda académica que reúne horario, tareas, exámenes, faltas y calificaciones; avisa antes de cada entrega y antes de perder el derecho por faltas, y calcula cuánto se necesita para aprobar. Beneficio: **ninguna entrega ni límite de faltas se pasa sin aviso**. |
| **Funciones prioritarias** | 1. Captura rápida de tarea/examen con foto del pizarrón (cámara). 2. Recordatorios locales que llegan sin internet. 3. Registro de falta en 1 toque y alerta antes del límite. 4. Simulador de calificación ("¿cuánto necesito?"). 5. Inicio con "qué clase sigue" + widget en la pantalla del teléfono. 6. Funcionamiento sin conexión con sincronización posterior. |
| **Datos y seguridad** | Se guarda: nombre, correo, contraseña **cifrada (bcrypt)**, materias, horario, tareas, fotos adjuntas, faltas y calificaciones. **Solo el dueño** puede ver o modificar sus datos (lo valida el servidor en cada consulta). Permisos Android: Internet, notificaciones, alarmas exactas y arranque del teléfono (para reprogramar recordatorios); la cámara se usa a través del selector del sistema solo cuando el usuario adjunta una foto. Ver [datos-seguridad.md](datos-seguridad.md). |
| **Diferenciación móvil** | Cámara para fotografiar indicaciones, notificaciones programadas por el propio teléfono, widget de pantalla de inicio, uso sin conexión y captura en 3 toques durante la clase. Ver [web-vs-movil.md](web-vs-movil.md). |
| **Alcance y riesgos** | Se entrega: el MVP descrito, APK firmado, web de consulta, API y documentación. **No** se entrega: publicación en Google Play, iOS, integración con el sistema escolar oficial ni recordatorios push desde servidor. Riesgos: el servidor corre en la PC del equipo (el teléfono debe estar en la misma red o el servidor debe subirse a un hosting); algunos fabricantes (Xiaomi, Huawei) retrasan notificaciones por ahorro de batería — mitigado con la **guía de batería** dentro de la app. |

## Pregunta de validación

> *Si elimináramos la app móvil y dejáramos únicamente el sistema web, ¿qué capacidad útil perdería el usuario?*

Perdería **los avisos y la captura en el momento**. La web solo sirve si el estudiante se acuerda de abrirla
en una computadora. Sin la app:

- No llegan recordatorios antes de la entrega ni la alerta de "te queda 1 falta" (la web no puede notificar con el navegador cerrado).
- No puede fotografiar el pizarrón y dejar la foto ligada a la tarea en el mismo momento.
- No puede consultar su horario ni sus pendientes sin internet.
- No ve "qué clase sigue" desde la pantalla del teléfono sin abrir nada (widget).

## Responsabilidades iniciales del equipo

| Integrante | Rol principal | Rol de apoyo |
|---|---|---|
| Santiago Asahel Pech Ake | Lógica/servicios (API client, SQLite, sincronización offline y notificaciones) | Integración y administración del repositorio |
| Nataly Marisol Santos Miam | Interfaz de la app (pantallas Flutter, diseño responsivo, ícono e identidad visual) | Documentación de diseño y manual de usuario |
| Oscar Michel Matos May | Base de datos y seguridad (esquema PostgreSQL, JWT, aislamiento por usuario y validaciones) | Pruebas automatizadas del backend y bitácora |
| Genaro Aurelio Antonio Pacheco | Pruebas, APK firmado, widget nativo Android y versión web en React | Análisis, matriz de validación y presentación pitch |

## Fuente de la información

- **Experiencia directa del equipo** como estudiantes de 4.º cuatrimestre de la Universidad Tecnológica Metropolitana (UTM), observando el flujo real durante las clases, cambios de laboratorio y traslados en transporte público sin datos móviles.
- **Consulta breve con compañeros de grupo (18 de noviembre de 2026, 12 estudiantes de 4.º cuatrimestre de TI en la UTM):**
  - 10 de 12 comentaron que anotan tareas fotografiando el pizarrón o en mensajes de WhatsApp y que esas fotos se pierden en la galería.
  - 9 de 12 indicaron que no llevan un conteo exacto de sus inasistencias por materia hasta que el profesor pasa lista antes de las evaluaciones parciales.
  - 11 de 12 señalaron que calculan manualmente en calculadora o papel cuánto necesitan sacar en la última unidad para alcanzar la calificación mínima aprobatoria.
- **Criterio académico y control de asistencia en la UTM:**
  - En el modelo cuatrimestral por competencias de la UTM, la calificación mínima aprobatoria es de **8.0** (escala de 0 a 10) y el estudiante requiere cubrir al menos el **80 % – 85 % de asistencia** por asignatura/unidad (equivalente a un límite práctico de **3 a 6 faltas por cuatrimestre** según las horas semanales de cada materia) para conservar el derecho a evaluación ordinaria; las inasistencias con justificante médico o institucional no se descuentan del límite.
