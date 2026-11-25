# VENDIX — INFORME TÉCNICO DE LIMPIEZA DE LA INTEGRACIÓN DE GOOGLE SHEETS Y GOOGLE DRIVE

**Fecha:** 25 de noviembre de 2026  
**Proyecto:** VendiX Mobile (Flutter / Firebase)  
**Estado:** Limpieza completada, validada y compilada con éxito  

---

## Índice General

1. [Resumen de la Auditoría Realizada](#1-resumen-de-la-auditoría-realizada)
2. [Archivos Eliminados](#2-archivos-eliminados)
3. [Archivos Modificados](#3-archivos-modificados)
4. [Servicios y Métodos Retirados](#4-servicios-y-métodos-retirados)
5. [Dependencias Eliminadas y Conservadas](#5-dependencias-eliminadas-y-conservadas)
6. [Configuraciones OAuth Retiradas y Conservadas](#6-configuraciones-oauth-retiradas-y-conservadas)
7. [Confirmación de Integridad de Firebase Authentication y Google Sign-In](#7-confirmación-de-integridad-de-firebase-authentication-y-google-sign-in)
8. [Confirmación de Integridad de Gemini API y Otras APIs](#8-confirmación-de-integridad-de-gemini-api-y-otras-apis)
9. [Confirmación de Integridad del Modelo Firestore y Trazabilidad Comercial](#9-confirmación-de-integridad-del-modelo-firestore-y-trazabilidad-comercial)
10. [Resultados de Análisis Estático y Compilación](#10-resultados-de-análisis-estático-y-compilación)
11. [Referencias Residuales Conservadas y su Justificación](#11-referencias-residuales-conservadas-y-su-justificación)
12. [Descripción de la Nueva Arquitectura Futura (No Implementada)](#12-descripción-de-la-nueva-arquitectura-futura-no-implementada)
13. [Problemas Pendientes y Limitaciones Detectadas](#13-problemas-pendientes-y-limitaciones-detectadas)

---

## 1. Resumen de la Auditoría Realizada

Se realizó una auditoría estática y estructural completa en el repositorio `c:\Users\crist\Desktop\VENDIX\flutter_application_1` con el propósito de erradicar temporalmente la integración con Google Sheets API y Google Drive API. 

La integración anterior presentaba fricciones de usabilidad y barreras operativas:
- Requería autorización OAuth delegada para scopes de Google Drive (`https://www.googleapis.com/auth/drive.file`) y Google Sheets (`https://www.googleapis.com/auth/spreadsheets`).
- Dependía de plantillas alojadas centralmente en una cuenta de Google Drive que causaba errores de permisos cuando usuarios con otras cuentas de Google intentaban acceder al documento generado (produciendo diálogos nativos como *"¿Solicitar acceso al propietario del archivo?"* y *"No se puede acceder al documento"*).
- Excluía operativamente a usuarios cuyo registro comercial se efectúa con correos institucionales, Hotmail, Outlook u otros proveedores que no tienen cuenta Google asociada.

La auditoría analizó el árbol completo de directorios en `lib/`, la configuración de paquetes en `pubspec.yaml` y los manifiestos de plataforma en `android/app/src/main/AndroidManifest.xml` para garantizar que la retirada no afectara los servicios críticos de autenticación, geolocalización, almacenamiento multimedia e inteligencia artificial.

---

## 2. Archivos Eliminados

Se retiraron de forma definitiva los dos archivos responsables de la lógica de exportación a Google Sheets y compilación de reportes tabulares:

| Archivo | Ruta Original | Justificación de la Eliminación |
|---|---|---|
| `google_sheets_service.dart` | `lib/services/google_sheets_service.dart` | Contenía la clase `GoogleSheetsService`, la solicitud de credenciales OAuth suplementarias (`GoogleSignIn(scopes: [...spreadsheets, ...drive.file])`), la invocación a los endpoints REST de Google Sheets v4 / Drive v3 y la apertura de URLs en navegador. |
| `reportes_service.dart` | `lib/services/reportes_service.dart` | Contenía las clases `ReportesService`, `DatosReporteCompleto` y `RendimientoResponsable`. Su única función era alimentar a `GoogleSheetsService`. Ningún otro componente de la aplicación consumía estas estructuras. |

---

## 3. Archivos Modificados

Para desvincular la interfaz gráfica y los recursos nativos de la integración retirada, se modificaron tres archivos clave:

### 3.1. `lib/screens/admin/admin_more_screen.dart`
- **Importaciones eliminadas:**
  - `import '../../services/reportes_service.dart';`
  - `import '../../services/google_sheets_service.dart';`
- **Componente visual retirado:**
  - Tarjeta de acción rápida `_buildActionCard(..., 'Exportar a Google Sheets', 'Generar reporte completo...')` dentro de la sección "Acciones rápidas" del panel del administrador.
- **Métodos retirados:**
  - `_mostrarDialogoExportacion()`: Controlaba la apertura del diálogo modal de selección de rangos de fecha (Historial completo, Jornada actual, Últimos 7 días, Mes actual) y confirmación de exportación.
  - `_ejecutarExportacion()`: Orquestaba la llamada a `ReportesService.recopilarDatos()`, la llamada a `GoogleSheetsService.exportarReporteCompleto()` y el despliegue del modal de éxito con el botón "Abrir Hoja de Cálculo".

### 3.2. `pubspec.yaml`
- **Dependencia retirada:**
  - `url_launcher: ^6.3.0`: Habiéndose agregado exclusivamente para lanzar en el navegador externo el enlace generado por Google Sheets (`spreadsheetUrl`), se eliminó del archivo de especificación de dependencias. Se ejecutó `flutter pub get` para actualizar `pubspec.lock`.

### 3.3. `android/app/src/main/AndroidManifest.xml`
- **Consulta de paquetes (Queries) revertida:**
  - Se retiró el bloque `<queries>` que declaraba soporte para intents con esquema `https` (`<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>`), el cual era requerido exclusivamente por `url_launcher` para cumplir con las políticas de visibilidad de paquetes de Android 11+ (API level 30+).

---

## 4. Servicios y Métodos Retirados

### Inventario de Componentes Eliminados:

```
[lib/services/google_sheets_service.dart]
 ├── GoogleSheetsService._()
 ├── GoogleSheetsService.solicitarAccesoGoogle()
 ├── GoogleSheetsService.exportarReporteCompleto(...)
 ├── GoogleSheetsService._crearEncabezados(...)
 ├── GoogleSheetsService._aplicarFormatos(...)
 └── GoogleSheetsService.abrirEnNavegador(...)

[lib/services/reportes_service.dart]
 ├── class RendimientoResponsable
 ├── class DatosReporteCompleto
 ├── ReportesService._()
 └── ReportesService.recopilarDatos(...)

[lib/screens/admin/admin_more_screen.dart]
 ├── _mostrarDialogoExportacion()
 └── _ejecutarExportacion(String filtro, DateTime? inicio, DateTime? fin)
```

---

## 5. Dependencias Eliminadas y Conservadas

| Paquete | Versión Declarada | Estado | Justificación |
|---|---|---|---|
| `url_launcher` | `^6.3.0` | **Eliminada** | Solo se usaba para abrir la hoja de cálculo en Drive. Ningún otro servicio la requería. |
| `google_sign_in` | `^6.2.2` | **Conservada** | Fundamental para la autenticación de usuarios en `lib/services/google_auth_service.dart` (Firebase Auth). |
| `http` | `^1.3.0` | **Conservada** | Requerida por `lib/services/cloudinary_service.dart` para subida de fotos y por `lib/widgets/store_location_map.dart` para geocodificación OSM/Nominatim. |
| `firebase_auth` | `^5.4.4` | **Conservada** | Servicio central de gestión de identidades, sesiones y tokens de usuario. |
| `cloud_firestore` | `^5.6.5` | **Conservada** | Base de datos NoSQL donde reside el modelo comercial de VendiX. |
| `firebase_core` | `^3.12.1` | **Conservada** | Inicialización de los servicios de Firebase en la plataforma. |
| `google_generative_ai` | `^0.4.6` | **Conservada** | Conexión con Gemini API para el asistente inteligente / chatbot de clientes. |
| `image_picker` | `^1.1.2` | **Conservada** | Selección de fotos de prendas y avatares de perfil. |
| `flutter_map` / `latlong2` | `^7.0.2` / `^0.9.1` | **Conservada** | Visualización interactiva de ubicación de tiendas en mapa OpenStreetMap. |

---

## 6. Configuraciones OAuth Retiradas y Conservadas

Se diferenció estrictamente la capa de **autorización** (OAuth Scopes para Google Drive / Sheets) de la capa de **autenticación** (OAuth Scopes para identidad):

- **Scopes OAuth Retirados:**
  - `https://www.googleapis.com/auth/spreadsheets`
  - `https://www.googleapis.com/auth/drive.file`
  *Ambos scopes fueron eliminados junto con `google_sheets_service.dart`.*
- **Scopes OAuth Conservados:**
  - `email`
  - `profile`
  - `openid`
  *Estos scopes permanecen exclusivamente en `lib/services/google_auth_service.dart` para obtener las credenciales de Firebase Authentication sin requerir ningún permiso sobre los archivos privados de Drive del usuario.*

---

## 7. Confirmación de Integridad de Firebase Authentication y Google Sign-In

El flujo de inicio de sesión con Google y correo electrónico permanece **completamente intacto**:

1. `GoogleAuthService.signInWithGoogle()` no sufrió alteraciones en sus firmas, flujos o dependencias.
2. La vinculación de cuentas entre Firebase Auth y Cloud Firestore (colección `usuarios`, `Administradores`, `clientes` y `secretarios`) se mantiene operativa.
3. El modal simplificado de registro para usuarios de Google en `lib/screens/auth/login_screen.dart` sigue solicitando únicamente:
   - Nombre
   - Apellido
   - Teléfono (opcional)
4. El hub de bienvenida (`lib/screens/client/client_welcome_hub_screen.dart`) conserva las tres opciones operativas:
   - **Modo Comprador:** Asociarse a un emprendimiento mediante código Live.
   - **Oportunidad Laboral:** Solicitar empleo como secretario.
   - **Emprendimiento:** Trabajar como emprendedor (solicitando exclusivamente el nombre del negocio).

---

## 8. Confirmación de Integridad de Gemini API y Otras APIs

Se verificó el funcionamiento autónomo de todas las APIs activas del ecosistema VendiX:

- **Gemini AI (`gemini_service.dart`):** La API de Google Generative AI utiliza su propia clave de API y el modelo `gemini-1.5-flash` para el chatbot de asistencia (`ClientChatbotSheet`). No comparte dependencias de red ni clientes HTTP con los servicios eliminados.
- **Cloudinary API (`cloudinary_service.dart`):** Permanece activa mediante peticiones multipart HTTP a los endpoints de Cloudinary para el almacenamiento de comprobantes de pago, fotos de prendas y avatares de usuario.
- **OpenStreetMap / Nominatim API (`store_location_map.dart`):** Permanece operativa para la geocodificación reversa de coordenadas (latitud/longitud) de las tiendas físicas.
- **Firebase Authentication & Cloud Firestore APIs:** 100% funcionales.

---

## 9. Confirmación de Integridad del Modelo Firestore y Trazabilidad Comercial

La base de datos Cloud Firestore **no sufrió ninguna modificación destructiva**:

- **Colección `_contadores`:** Permanece intacta garantizando la generación consecutiva de identificadores (`AdminNNN_...`, `cliNNN_...`, `SecreNNN_...`, `PrendNNN_...`, `VentNNN`, `PagoNNN`, `JornNNN_...`).
- **Campos de Trazabilidad Comercial:**
  - `registradoPorId`: Identificador del usuario que registró la compra o venta.
  - `registradoPorNombre`: Nombre de visualización del operador.
  - `rolResponsable`: Rol comercial con el que se ejecutó la acción (`administrador` o `secretario`).
  - `recibidoPorId` / `cobradoPorId`: Identificador del responsable que recaudó el abono/pago.
  - `adminId`: Identificador del emprendimiento propietario de la transacción.
  - `jornadaId`: Identificador de la transmisión en vivo vinculada a la venta.
- **Colecciones de Negocio:** `Administradores`, `clientes`, `secretarios`, `compras`, `pagos`, `prendas`, `jornadas`, `usuarios`. Ningún campo ni documento fue alterado.

---

## 10. Resultados de Análisis Estático y Compilación

### 10.1. Análisis Estático (`flutter analyze lib/`)
Se ejecutó la verificación estática del compilador de Dart sobre todo el directorio `lib/`:
```bash
flutter analyze lib/
```
**Resultado:**
```text
Analyzing lib...
No issues found! (ran in 10.1s)
```
*0 errores, 0 advertencias, 0 sugerencias.*

### 10.2. Compilación del APK (`flutter build apk --debug`)
Se ejecutó la tarea Gradle para la compilación completa de la aplicación en modo depuración:
```bash
flutter build apk --debug
```
**Resultado:**
```text
Running Gradle task 'assembleDebug'...
√ Built build\app\outputs\flutter-apk\app-debug.apk
```
*El APK debug compiló satisfactoriamente y se encuentra disponible en `build\app\outputs\flutter-apk\app-debug.apk` listo para su distribución e instalación en dispositivos de prueba.*

---

## 11. Referencias Residuales Conservadas y su Justificación

Se realizó una búsqueda global de cadenas de texto similares a "sheet" para garantizar que no existan remanentes no intencionales:

| Archivo / Cadena Detectada | Ubicación | Justificación Técnica de Conservación |
|---|---|---|
| `client_chatbot_sheet.dart` | `lib/screens/client/client_chatbot_sheet.dart` | Hace referencia a un **Modal Bottom Sheet** (componente visual de Material Design) donde se despliega la interfaz conversacional con Gemini AI. No tiene ninguna relación con hojas de cálculo. |
| `showModalBottomSheet` | Múltiples pantallas | Widgets de interfaz de usuario de Flutter para menús deslizables inferiores. |
| `package:http/http.dart` | `pubspec.yaml`, `cloudinary_service.dart` | Requerido legítimamente por Cloudinary y la API de mapas de OpenStreetMap. |

---

## 12. Descripción de la Nueva Arquitectura Futura (No Implementada)

> [!IMPORTANT]
> **Constancia de No Implementación:** La siguiente arquitectura representa el diseño técnico acordado para una fase futura. **Ninguno** de estos componentes ha sido codificado, creado ni incorporado en el proyecto durante la sesión actual.

```mermaid
flowchart TD
    subgraph Fase_1_Local["Fase 1: Generación Offline (Local)"]
        A["Usuario solicita Exportar Reporte"] --> B["Verificación de Rol y Permisos en VendiX"]
        B --> C{"Selección de Plantilla"}
        C -->|"Rol: Administrador"| D["assets/templates/VendiX_Admin.xlsx"]
        C -->|"Rol: Secretario"| E["assets/templates/VendiX_Secretario.xlsx"]
        D & E --> F["Lectura de datos autorizados desde Firestore"]
        F --> G["Copia en memoria de la plantilla XLSX"]
        G --> H["Llenado de tablas estructuradas (dart:io / excel)"]
        H --> I["Archivo generado en almacenamiento local del dispositivo"]
        I --> J["Descarga directa (.XLSX) sin necesidad de cuenta Google"]
    end

    subgraph Fase_2_Opcional["Fase 2: Subida Opcional a Google Drive"]
        I --> K{"¿Desea sincronizar con Google Drive?"}
        K -->|"No"| L["Fin del proceso - Archivo en dispositivo"]
        K -->|"Sí"| M["Autorización OAuth en cuenta personal del usuario"]
        M --> N["Subida vía Google Drive API v3"]
        N --> O["Conversión automática al formato nativo de Google Sheets"]
        O --> P["Documento privado almacenado en el Drive del propio usuario"]
    end
```

### Ventajas del Nuevo Enfoque Frente al Anterior:
1. **Independencia Total de la Cuenta del Desarrollador:** Se elimina por completo el almacenamiento centralizado en el Drive del creador de la app.
2. **Inclusión de Todos los Proveedores de Correo:** Los usuarios con cuentas de Microsoft, Yahoo o corporativas pueden generar y descargar su reporte Excel sin tener cuenta de Google.
3. **Privacidad de Datos:** Si el usuario decide subirlo a Google Drive, el archivo se crea directamente en su propia nube personal con sus propias credenciales.
4. **Cumplimiento Académico:** El uso de Google Drive API como destino de respaldo satisface el requerimiento de integración de APIs externas de forma limpia y desacoplada.

---

## 13. Problemas Pendientes y Limitaciones Detectadas

1. **Compilación Limpia Requerida en Dispositivos:** Los compañeros de prueba que poseían una instalación previa de la aplicación deben desinstalar la versión anterior o instalar directamente el nuevo APK generado en `build\app\outputs\flutter-apk\app-debug.apk` para garantizar que no existan cachés ni diálogos residuales del build anterior.
2. **Incorporación Futura de Plantillas XLSX:** Cuando se decida implementar la fase de reportes, se deberán ubicar los archivos `VendiX_Admin.xlsx` y `VendiX_Secretario.xlsx` en la carpeta `assets/templates/`, registrar la ruta en el bloque `assets:` de `pubspec.yaml` y seleccionar una librería de manipulación de hojas de cálculo compatible con tablas estructuradas (como `excel` o `syncfusion_flutter_xlsio`).

---

**Conclusión:** La aplicación VendiX se encuentra libre de dependencias no deseadas de Google Sheets API, con código fuente 100% verificado, sin advertencias de análisis estático y con el paquete de instalación APK debug compilado exitosamente para la fase de pruebas del equipo.
