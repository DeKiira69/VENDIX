# Adaptación e Integración Integral del Backup de Cevallos en la Raíz de VENDIX

- **Proyecto:** VENDIX — Gestión de Ventas en Vivo (Live Shopping)
- **Editor:** Henry Cevallos
- **Fecha:** 30 de octubre de 2026
- **Documento:** Integración de backup
- **Origen:** backups/backup_cevallos_23102026/vendix/
- **Destino:** Raíz del proyecto flutter_application_1/
- **Estado Final:** 100% Integrado y Verificado (flutter analyze lib/: 0 errores; flutter build web: éxito)

---

## 1. Análisis del Markdown de Cevallos (`2026-10-30_cevallos_cambios_hoy.md`)

Del análisis exhaustivo del informe de Cevallos se identificaron 5 ejes principales de innovación que no estaban en la raíz:

1. **Reparación del Manifiesto Nativo Android (`AndroidManifest.xml`):**
   - Tenía secuencias rotas de escape de PowerShell (`` `r`n ``) y faltaba el permiso `INTERNET`.
2. **Servicio de Foto de Perfil estilo WhatsApp (`PerfilFotoService`):**
   - Módulo para subir foto con cámara/galería, compresión a 512px (calidad 75%), Base64 y guardado reactivo en `fotos_perfil/{uid}`.
3. **Optimización de Alta Velocidad en Login (`< 10 ms`):**
   - Lectura prioritaria desde la caché local de Firestore (`Source.cache`).
   - Consultas de respaldo en paralelo (`Future.wait`) con timeout.
   - Auto-login con verificación de sesión existente en `initState()`.
4. **Optimización de Streams Compartidos (`ClientService`):**
   - Memorización con `.asBroadcastStream()` para evitar abrir 9 conexiones simultáneas al cargar `ClientShell`.
   - Limpieza de caché en memoria (`ClientService.limpiarCache()`) al cerrar sesión.
5. **Edición de Datos Personales en el Perfil de Cliente:**
   - Hoja modal interactiva para actualizar nombre, teléfono y dirección física sincronizando en Firestore y en `FirebaseAuth.updateDisplayName`.

---

## 2. Archivos y Módulos Adaptados a la Raíz

| Archivo / Componente | Origen (Cevallos) | Estado en Raíz | Descripción del Cambio / Adaptación |
| :--- | :--- | :--- | :--- |
| **`pubspec.yaml`** | `vendix/pubspec.yaml` | ✅ Integrado | Se añadió la dependencia oficial `image_picker: ^1.2.4` para la cámara y galería. |
| **`android/.../AndroidManifest.xml`** | `vendix/android/...` | ✅ Corregido | Se eliminó el escape literal `` `r`n ``, se mantuvo `portrait` y se agregó `<uses-permission android:name="android.permission.INTERNET"/>`. |
| **`lib/services/perfil_foto_service.dart`** | `vendix/lib/services/...` | ✅ Creado en raíz | Servicio completo de avatar estilo WhatsApp, selector modal y compresión. |
| **`lib/services/client_service.dart`** | `vendix/lib/services/...` | ✅ Actualizado | Incorpora caché broadcast de streams, gestión de conexiones y método `limpiarCache()`. |
| **`lib/screens/client/client_home_screen.dart`** | `vendix/lib/screens/client/...` | ✅ Actualizado | Elimina pantalla en blanco inicial; renderizado instantáneo con fallback de Auth mientras conecta Firestore. |
| **`lib/screens/client/client_profile_screen.dart`** | `vendix/lib/screens/client/...` | ✅ Actualizado | Formulario modal para editar datos personales, avatar WhatsApp y cierre de sesión seguro. |
| **`lib/screens/secretary/more_screen.dart`** | `vendix/lib/screens/secretary/...` | ✅ Actualizado | Avatar interactivo para secretarias, acceso a cambio de foto y cierre de sesión con purga de caché. |
| **`lib/screens/secretary/jornadas_screen.dart`** | `vendix/lib/screens/secretary/...` | ✅ Incorporado | Módulo para crear y gestionar sesiones Live de ventas con catálogo demo. |
| **`lib/data/datos_prueba.dart`** | `vendix/lib/data/...` | ✅ Actualizado | Modelos de soporte (`JornadaDemo`, `jornadasDemo`) requeridos por el módulo de jornadas. |
| **`lib/screens/auth/login_screen.dart`** | Híbrido perfeccionado | ✅ Adaptado | **Fusión perfecta:** Conserva la lógica de **Secretario en estado Pendiente**, selector animado de registro, y adopta la caché de login ultrarrápida (<10ms), consultas concurrentes y auto-login. |
| **`run_brave.bat`** | `vendix/run_brave.bat` | ✅ Copiado a raíz | Script lanzador multiplataforma (Chrome, Edge, Brave, MuMuPlayer y Teléfono Android por USB). |
| **`artefacts/2026-10-30_cevallos_cambios_hoy.md`** | `vendix/artefacts/...` | ✅ Respaldado en raíz | Informe original de Cevallos copiado para trazabilidad del equipo. |

---

## 3. Scripts Lanzadores (.bat y .ps1) Adaptados

Se analizó la suite de scripts `.bat` del backup de Cevallos:
- Ambos archivos (`run_web.bat` y `run_brave.bat`) son lanzadores inteligentes con menú numérico interactivo:
  - `[1]` Google Chrome
  - `[2]` Microsoft Edge
  - `[3]` Brave Browser (detecta instalación en `LocalAppData` y `Program Files`)
  - `[4]` Teléfono físico Android por USB (`nrk7v8x47pibhyjj` / `21061110AG`)
  - `[5]` Emulador MuMuPlayer con auto-conexión ADB a `127.0.0.1:16384` y `127.0.0.1:7555`
- Además, levantan el servidor web local con encabezados `Cache-Control: no-store, no-cache` para evitar que los navegadores guarden versiones viejas de la app.
- Se mantuvo en la raíz `run_web.bat` y se copió también `run_brave.bat` para que tengas ambas opciones a mano.

---

## 4. Verificación de Compilación y Estado Actual

1. **`flutter pub get`:** Paquetes actualizados e instalados (`image_picker 1.2.4` activo).
2. **`flutter analyze lib/`:**
   ```text
   Analyzing lib...
   No issues found! (ran in 3.0s)
   ```
3. **`flutter build web --release`:**
   ```text
   Compiling lib\main.dart for the Web... 136,6s
   √ Built build\web
   ```
4. **Servidor Local Activo:**
   El servidor en `http://localhost:5000` está corriendo con el bundle actualizado.
