# MiSemestre UTM — Aplicación Móvil Android (Flutter)

Agenda académica offline-first diseñada para estudiantes de la Universidad Tecnológica de la Mixteca (UTM). Permite gestionar materias, horarios semanales, tareas y exámenes con fotografías, registro de asistencias/faltas, simulación de calificaciones y recordatorios confiables mediante notificaciones locales.

---

## 📋 Requisitos del Entorno

- **Flutter SDK:** 3.13+ (compatible con Dart 3.x)
- **Java:** JDK 17 o superior
- **Android SDK:** `compileSdk = 37`, `minSdkVersion = 21`
- **Dispositivo:** Emulador Android (API 26+) o dispositivo físico con depuración USB activada.
- **Backend MiSemestre UTM:** Servicio Node.js/Express ejecutándose en `http://localhost:3000`.

---

## 🌐 Configuración de la URL del Servidor

La aplicación permite configurar la URL base del API de forma dinámica sin necesidad de recompilar:

1. **Desde un emulador de Android:**
   - La máquina anfitriona (`localhost`) es accesible en:  
     `http://10.0.2.2:3000`
2. **Desde un teléfono físico:**
   - Debe conectarse a la misma red Wi-Fi que la computadora y usar la IP local:  
     `http://192.168.1.X:3000`
3. **Cambiar la URL en la aplicación:**
   - Ve a la pantalla de **Ajustes** (ícono de engrane en Inicio o menú ⋮ en Materias).
   - Selecciona **Configurar servidor**.
   - Ingresa la URL base deseada y presiona **Guardar**.

---

## 🚀 Cómo Ejecutar en Desarrollo

1. Obtener dependencias:
   ```bash
   cd app
   flutter pub get
   ```

2. Ejecutar pruebas unitarias y de widgets:
   ```bash
   flutter test
   ```

3. Analizar el código:
   ```bash
   flutter analyze
   ```

4. Lanzar en el emulador o dispositivo conectado:
   ```bash
   flutter run
   ```

---

## 📦 Compilación de APK

### Generar APK de depuración (Debug)
```bash
flutter build apk --debug
```
El archivo generado se ubicará en:  
`build/app/outputs/flutter-apk/app-debug.apk`

### Generar APK para producción (Release)
```bash
flutter build apk --release
```
El archivo optimizado se ubicará en:  
`build/app/outputs/flutter-apk/app-release.apk`

---

## ✨ Características Principales

- **Arquitectura Offline-First:** Base de datos local SQLite con sincronización bidireccional incremental (`sync_status: synced | pending_*`).
- **Recordatorios Confiables:** Notificaciones locales programadas en el dispositivo mediante `flutter_local_notifications` y soporte de alarmas exactas con respaldo inexacto mientras el dispositivo está inactivo (`AndroidScheduleMode.inexactAllowWhileIdle`).
- **Navegación desde Notificaciones:** Al presionar un recordatorio, la app se abre directamente en el detalle de la tarea programada.
- **Widget de Pantalla de Inicio:** Widget nativo (`home_widget`) que muestra la próxima clase y los pendientes de hoy.
- **Captura Rápida de Tareas:** Detección automática de la materia en curso y asignación inteligente de la fecha de entrega en 3 toques.
