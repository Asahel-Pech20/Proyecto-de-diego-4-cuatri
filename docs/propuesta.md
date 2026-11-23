# Propuesta del proyecto — MiSemestre UTM

> Entregable 1 del proyecto final. Formato de la sección 4 del documento de lineamientos.
> Las partes marcadas con ✏️ las completa el equipo con su información real.

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

> ✏️ Ajustar a lo que realmente hizo cada quien. Deben poder explicarlo en la exposición.

| Integrante | Rol principal | Rol de apoyo |
|---|---|---|
| Santiago Asahel Pech Ake | Lógica/servicios (API, sincronización) | Integración y repositorio |
| Nataly Marisol Santos Miam | Interfaz de la app (pantallas, identidad visual) | Documentación |
| Oscar Michel Matos May | Base de datos y seguridad | Pruebas del backend |
| Genaro Aurelio Antonio Pacheco | Pruebas, APK y versión web | Análisis y presentación |

## Fuente de la información

> ✏️ Anotar con quién se habló o qué se observó (PDF, sección 5: "Registraremos de dónde obtuvimos la información").

- Experiencia directa del equipo como estudiantes de la UTM (4.º cuatrimestre).
- ✏️ Conversación / encuesta breve con compañeros de grupo: número de personas, fecha y respuestas principales.
- ✏️ Reglamento o criterio de faltas de la universidad/profesores (límite de faltas por materia).
