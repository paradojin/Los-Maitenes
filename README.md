# Los Maitenes

Aplicación móvil (Flutter + Firebase) para la gestión de un camping/alojamiento:
registro de grupos, cobros y control de accesos.

## Funcionalidades

- **Login de operador**: cada persona del staff ingresa su nombre; queda registrado en cada grupo que crea.
- **Registro rápido de grupos**: responsable, RUT/celular/patente (opcionales), adultos/niños, tipo de estadía (Por el día / Acampada).
- **Cobros**: pago total o por abonos, con métodos Efectivo / Transferencia / Tarjeta.
  - **Acampada** = `(N-1) noches × tarifa acampada + último día × tarifa día`.
  - **Regla de las 10:30**: si el grupo se retira antes de las 10:30, solo se cobran las noches.
- **Estado de un vistazo**: cada grupo muestra Al día (verde) · Abono (ámbar) · Pendiente (rojo).
- **Finanzas**: recaudado por día/semana/mes, desglose por método y estado de cobro de los grupos.
- **Lista negra**: bloqueo por RUT o patente, con aviso al registrar un grupo coincidente.

## Requisitos

- Flutter (canal stable) y un JDK 17.
- Android SDK (para compilar/instalar en Android).

## Ejecutar en desarrollo

```bash
flutter pub get
flutter run
```

## Compilar APK de release

```bash
flutter build apk --release
# salida: build/app/outputs/flutter-apk/app-release.apk
```

## Descargar la app (Android)

Escanea el código QR con tu teléfono o abre el enlace de descarga directa:

<p align="center">
  <img src="los-maitenes-v2-qr.png" width="240" alt="QR de descarga - Los Maitenes">
</p>

**Descarga directa (siempre la última versión):** [los-maitenes.apk](https://github.com/paradojin/Los-Maitenes/releases/latest/download/los-maitenes.apk)

Descarga el `.apk`, ábrelo en el teléfono y habilita "instalar apps de origen desconocido".
La última versión siempre está en la sección **[Releases](https://github.com/paradojin/Los-Maitenes/releases)**.

## Stack

- Flutter (Dart), Material 3
- Firebase: Cloud Firestore + Authentication (anónima)
- `shared_preferences` para la sesión local del operador
