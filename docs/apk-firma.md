# Generar el APK firmado

> Entregable 7. La identidad del APK es propia: nombre **MiSemestre UTM**, paquete `mx.utm.app`,
> ícono propio (`app/assets/icon/`) y versión `1.2.0 (3)` tomada de `app/pubspec.yaml`.

## 1. Clave de firma (una sola vez, fuera del repositorio)

```powershell
keytool -genkeypair -v -keystore C:\ruta\fuera\del\repo\misemestre-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias misemestre
```

Guarda la keystore y sus contraseñas en un lugar seguro del equipo (no en GitHub, no en el chat del grupo).
**Si se pierde, no se pueden publicar actualizaciones con la misma firma.**

## 2. `app/android/key.properties` (ignorado por Git)

```properties
storePassword=<contraseña>
keyPassword=<contraseña>
keyAlias=misemestre
storeFile=C:/ruta/fuera/del/repo/misemestre-release.jks
```

`app/android/app/build.gradle.kts` lee este archivo. Si no existe, la compilación cae a la clave de debug
(sirve para probar, **no** para entregar).

## 3. Compilar

```powershell
cd app
flutter pub get
flutter test
flutter build apk --release
```

Sale en `app/build/app/outputs/flutter-apk/app-release.apk`. Verificar la firma:

```powershell
& "$env:ANDROID_HOME\build-tools\36.0.0\apksigner.bat" verify --print-certs app\build\app\outputs\flutter-apk\app-release.apk
```

Debe mostrar `CN=MiSemestre UTM` (no `CN=Android Debug`).

## 4. Ícono

Si se cambia `app/assets/icon/icon.png`, regenerar con `dart run flutter_launcher_icons`.

## 5. Instalar y probar

1. Pasar el APK al teléfono por un medio confiable (cable, Drive del equipo, *Releases* de GitHub).
2. Abrirlo y permitir la instalación de esa fuente **solo para esa app** (no desactivar protecciones generales).
3. Repetir la matriz de [pruebas.md](pruebas.md) en el teléfono y anotar la evidencia.

## ¿Por qué APK y no Google Play?

El objetivo es demostrar que sabemos compilar, firmar, instalar y distribuir. La cuenta de Google Play Console
cuesta 25 USD (pago único, referencia oct. 2026). Antes de publicar se revisará la información oficial vigente:
https://support.google.com/googleplay/android-developer/answer/6112435
