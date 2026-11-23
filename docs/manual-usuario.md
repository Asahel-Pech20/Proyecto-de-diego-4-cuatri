# MiSemestre UTM — Manual de usuario

MiSemestre UTM es tu agenda del semestre: horario, tareas, exámenes, faltas y calificaciones, con
recordatorios que llegan aunque no tengas internet.

> Los nombres en **negritas** son los textos exactos de los botones en la app.

## 1. Instalar la app

1. Descarga `MiSemestre-UTM-v1.0.0.apk` de la sección *Releases* del repositorio.
2. Ábrelo en tu teléfono Android. Si lo pide, permite **instalar apps de origen desconocido**.
3. Al abrir la app por primera vez, acepta el permiso de **notificaciones**: sin él no llegan los recordatorios.

## 2. Conectar con el servidor

La app guarda tus datos en un servidor (la API del proyecto). Hay que indicarle dónde está:

1. Toca el ícono **Configurar servidor** (arriba a la derecha, en la pantalla de inicio de sesión).
2. Escribe la dirección, por ejemplo `http://192.168.1.50:3000` (la IP de la computadora con el servidor; deben estar en la misma red Wi‑Fi).
3. Toca **Probar**. Si sale **¡Conexión exitosa con el servidor!**, toca **Guardar**.

Si cambias de red, la IP de la computadora cambia y hay que repetir este paso.

## 3. Crear cuenta e iniciar sesión

- Primera vez: toca **Regístrate aquí**, escribe tu nombre, correo institucional y una contraseña de al menos 8 caracteres.
- Después: escribe correo y contraseña y toca **Iniciar Sesión**. La sesión dura 30 días.
- Si te equivocas de contraseña 10 veces en 15 minutos, la app te pide esperar antes de volver a intentar.

## 4. Pantalla de inicio

La pestaña **Inicio** muestra:
- La clase que está ocurriendo y la que **SIGUE**, con su hora y salón.
- **Pendientes de hoy** y **Para mañana**. Marca la casilla de una tarea para darla por hecha.

Abajo están las pestañas **Inicio**, **Horario**, **Tareas** y **Materias**.

## 5. Materias

1. En **Materias**, toca **Nueva Materia**.
2. Escribe el nombre y, si quieres, el docente y un color.
3. En **Parámetros académicos**: el límite de faltas que dio el profesor (déjalo vacío si no hay), la calificación mínima aprobatoria (por defecto 8) y la escala (por defecto 10).
4. Toca **Crear Materia**.

Toca una materia para ver sus tres secciones: **Simulador**, **Faltas** y **Evaluaciones**.

## 6. Horario

1. En **Horario**, elige el día y toca **Agregar Clase**.
2. Elige la materia, la hora de inicio y de fin, y el salón.
3. Si la clase se repite a la misma hora otros días, márcalos en **Repetir en otros días**: se crean todas de una vez.

Con el horario capturado, la pantalla de inicio sabe qué clase sigue.

## 7. Tareas y exámenes

Captura rápida en clase: toca **Nueva Tarea**, escribe el título y toca **Crear Tarea**. La app ya elige la materia de la clase en curso y pone como entrega su próxima clase.

Paso a paso:

1. Toca **Nueva Tarea** (en Inicio) o **Nueva Actividad** (en Tareas).
2. Elige **Tarea** o **Examen**, la materia y escribe el título.
3. **Fecha y hora de entrega**: elige el día en el calendario y la hora **tocando el reloj**.
4. **Foto adjunta** (opcional): toca **Adjuntar** → **Tomar foto con la cámara** o **Elegir de la galería**. Sirve para fotografiar el pizarrón o las indicaciones.
5. **Recordatorios anticipados**: elige cuándo avisarte (10 min, 30 min, 1 h, 2 h, 1 día o 2 días antes). Por defecto: 1 día y 2 horas antes.
6. Toca **Crear Tarea**.

En **Tareas** las verás agrupadas en **Vencidas**, **Para Hoy**, **Para Mañana** y **Después**, con filtros **Todas**, **Solo Tareas**, **Exámenes** y **Completadas**. Las que tienen foto muestran un ícono de imagen: tócalo para verla.

## 8. Faltas

1. Abre la materia y ve a **Faltas**.
2. **Falta de hoy (1 toque)** registra la falta con la fecha de hoy. **Otra fecha** te deja elegir el día y agregar una nota.
3. Si el profesor la justifica, activa el interruptor de la falta: las justificadas no cuentan para el límite.

La app no deja registrar dos faltas el mismo día en la misma materia. Te avisa con una notificación cuando te queda 1 falta y cuando superas el límite.

## 9. Calificaciones y simulador

1. En la materia, ve a **Evaluaciones** y agrega cada evaluación con su porcentaje (por ejemplo: Parcial 1, 30 %). Deja la calificación vacía si todavía no la presentas.
2. En **Simulador** verás:
   - **Puntos asegurados** y **Promedio actual**.
   - Cuánto necesitas promediar en lo que falta para aprobar.
   - **¿Y si saco...?**: mueve el deslizador para ver tu calificación final según lo que saques en lo pendiente.

Si los porcentajes no suman 100 %, la app te avisa.

## 10. Sin conexión

Todo funciona sin internet: consultar horario y pendientes, crear y editar tareas, registrar faltas. Lo que captures sin conexión muestra la etiqueta **Pendiente sync**. Al volver a tener red, toca **Sincronizar ahora** (ícono de flechas en Inicio) y la etiqueta desaparece. Las fotos se suben en ese momento.

Los recordatorios los programa el propio teléfono, así que llegan aunque no tengas datos.

## 11. Que no se pierdan los recordatorios (batería)

Algunos teléfonos (Xiaomi, Huawei, Samsung, Motorola, entre otros) cierran las apps en segundo plano para ahorrar batería y los avisos pueden llegar tarde o no llegar.

Al iniciar sesión, la app muestra la guía **Para que no se pierdan tus recordatorios**. También está en **Ajustes** (ícono de engrane en Inicio) → **Guía de batería**. Sigue sus pasos:

1. Toca **Abrir ajustes**: te lleva a la pantalla de optimización de batería del teléfono.
2. Busca **MiSemestre UTM** y elige **Sin restricciones** (o "No optimizar").
3. Si el teléfono lo pide, permite **Alarmas y recordatorios**.
4. En Xiaomi/HyperOS, activa además el **inicio automático** de la app.

Los nombres exactos cambian según la marca del teléfono.

**Tocar un recordatorio** abre directamente esa tarea, aunque la app estuviera cerrada.

## 11 bis. Widget en la pantalla de inicio

Mantén presionada la pantalla de inicio del teléfono → **Widgets** → **MiSemestre UTM** y agrégalo. Muestra la **siguiente clase** (materia, hora y aula) y las **tareas de hoy**, sin abrir la app. Tocarlo abre la app.

Se actualiza cada vez que creas, editas o completas una tarea y al sincronizar. Si pasas varias horas sin abrir la app, la clase que muestra puede quedarse atrasada hasta la próxima vez que la abras.

## 12. Versión web

Desde la computadora puedes consultar y editar lo mismo en la versión web (por defecto `http://localhost:5173` en la computadora del servidor). Usa el mismo correo y contraseña: los cambios aparecen en el teléfono al sincronizar.

## 13. Ajustes, cerrar sesión y borrar cuenta

Abre **Ajustes** con el ícono de engrane en **Inicio** (o menú ⋮ en **Materias**). Ahí están **Configurar servidor**, **Guía de batería**, **Cerrar sesión** y **Borrar mi cuenta**.

- **Cerrar sesión**: si tienes cambios sin sincronizar, la app te avisa antes; al cerrar sesión se borran del teléfono.
- **Borrar mi cuenta**: escribe **BORRAR** para confirmar. Elimina para siempre del servidor tus materias, tareas, fotos, faltas y calificaciones, cancela tus recordatorios y limpia el teléfono. Necesita internet: sin conexión no se borra nada. También se puede hacer desde la versión web (**Cuenta** → **Borrar definitivamente mi cuenta**).
