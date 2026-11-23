# MiSemestre UTM — Frontend Web (React + Vite)

Aplicación web para la gestión de la agenda académica de estudiantes de la Universidad Tecnológica de la Mixteca (UTM). Permite consultar y gestionar el horario semanal, tareas y exámenes con evidencias fotográficas, registro de asistencias/faltas, control de calificaciones y simulación de promedios finales.

---

## 🛠️ Tecnologías y Características

- **Framework:** React 19 con Vite
- **Enrutamiento:** `react-router-dom` v7
- **Estilos:** CSS puro responsivo (adaptable desde 360px en móviles hasta escritorio), aplicando la paleta institucional (Vino UTM `#7a1c2e`).
- **Pruebas unitarias:** Vitest
- **Seguridad:** Gestión de sesiones mediante JWT en `localStorage`, redirección automática a login ante expiración (401), y visualización de recursos estáticos protegidos mediante descarga en memoria (Blobs) con revocación segura de ObjectURLs.
- **Sin conexión:** La versión web se comunica en tiempo real con la API REST (`http://localhost:3000`).

---

## 📂 Estructura del Proyecto

```text
web/
├── src/
│   ├── api.js                 # Cliente central de la API REST (fetch, JWT, errores, blobs)
│   ├── utils.js               # Conversión de días, fechas ISO, cálculo de clases y simulador
│   ├── utils.test.js          # Pruebas unitarias en Vitest (13 pruebas)
│   ├── index.css              # Estilos globales y utilidades responsivas
│   ├── context/
│   │   └── AuthContext.jsx    # Estado global de autenticación (login, registro, logout, me)
│   ├── components/
│   │   ├── Navbar.jsx         # Barra de navegación con menú móvil responsive
│   │   ├── ProtectedRoute.jsx # Protección de rutas privadas
│   │   ├── Modal.jsx          # Componente modal accesible y reutilizable
│   │   └── AuthPhoto.jsx      # Visor de imágenes protegidas con token Bearer
│   ├── pages/
│   │   ├── Login.jsx          # Inicio de sesión y registro de cuenta
│   │   ├── Home.jsx           # Panel de inicio (clase en curso/próxima, pendientes de hoy y mañana)
│   │   ├── Schedule.jsx       # Horario semanal interactivo (Lunes a Sábado) con CRUD
│   │   ├── Tasks.jsx          # Lista y filtros de tareas/exámenes, fotos y recordatorios
│   │   ├── Subjects.jsx       # Gestión de materias con alerta de eliminación en cascada
│   │   ├── SubjectDetail.jsx  # Detalle de materia (Faltas, Calificaciones y Simulador "¿Y si saco...?")
│   │   └── Account.jsx        # Datos de perfil, cerrar sesión y borrado definitivo de cuenta
│   ├── App.jsx                # Configuración de rutas y layout general
│   └── main.jsx               # Punto de entrada de la aplicación
├── .env                       # Configuración local de variables de entorno
├── .env.example               # Plantilla de variables de entorno
├── package.json
└── vite.config.js
```

---

## 🚀 Requisitos Previos

- **Node.js:** Versión 18 o superior (probado con v24)
- **Backend MiSemestre UTM:** Corriendo en `http://localhost:3000` (el backend restringe CORS al origen `http://localhost:5173`).

---

## ⚙️ Configuración de Variables de Entorno

Copia el archivo `.env.example` a `.env` si es necesario:

```bash
cp .env.example .env
```

Contenido de `.env`:
```env
VITE_API_URL=http://localhost:3000
```

---

## 💻 Comandos de Ejecución

### 1. Instalar dependencias
```bash
cd web
npm install
```

### 2. Ejecutar servidor de desarrollo
Inicia el servidor local en el puerto `5173`:
```bash
npm run dev
```
Abre tu navegador en [http://localhost:5173](http://localhost:5173).

### 3. Ejecutar pruebas unitarias
Corre la suite completa de pruebas unitarias con Vitest:
```bash
npm test
```

### 4. Compilar para producción
Genera el bundle optimizado en la carpeta `dist/`:
```bash
npm run build
```

---

## 🧪 Pruebas Unitarias Verificadas

Se incluyen 13 pruebas unitarias en `src/utils.test.js` que validan la lógica central del negocio:

1. **Conversión de `dayOfWeek`:**
   - Mapeo bidireccional correcto entre convención UTM (`1` = Lunes, `7` = Domingo) y JavaScript `Date.getDay()` (`0` = Domingo, `1` = Lunes).
2. **Conversión de fechas y zona horaria:**
   - Transformación exacta entre `<input type="datetime-local">` (`YYYY-MM-DDTHH:mm`) y cadenas ISO con zona horaria requeridas por el backend.
3. **Determinación de Clase Actual y Próxima Clase:**
   - Detección precisa de clases en curso en el horario.
   - Selección de la siguiente clase del mismo día o del siguiente día de la semana.
4. **Simulador de Calificaciones "¿Y si saco...?":**
   - Cálculo exacto de nota necesaria en rubros pendientes.
   - Proyección con caso real: 7 en 30%, 8 en 30%, faltando 40% para aprobar con 8 $\rightarrow$ requiere 8.75; si saca 8 en el final $\rightarrow$ promedio proyectado de 7.7.
   - Detección de aprobados garantizados y escenarios matemáticamente imposibles.
