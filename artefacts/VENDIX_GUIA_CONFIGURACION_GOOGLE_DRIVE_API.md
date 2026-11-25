# VENDIX — GUÍA TÉCNICA DE CONFIGURACIÓN DE GOOGLE DRIVE API V3 Y OAUTH 2.0

**Destinatario:** Desarrollador del Proyecto VendiX / Evaluador Académico  
**Objetivo:** Guía paso a paso para configurar Google Cloud Console, habilitar Google Drive API v3, configurar OAuth 2.0, registrar huellas SHA-1/SHA-256 y diagnosticar errores  
**Fecha:** 25 de noviembre de 2026  
**Versión:** 2.0 (Arquitectura XLSX Local + Conversión Nativa en Drive)  

---

## Índice General

1. [Proyecto de Google Cloud y Vinculación con Firebase](#1-proyecto-de-google-cloud-y-vinculación-con-firebase)
2. [Habilitación de Google Drive API v3](#2-habilitación-de-google-drive-api-v3)
3. [Configuración de la Pantalla de Consentimiento OAuth (Google Auth Platform)](#3-configuración-de-la-pantalla-de-consentimiento-oauth-google-auth-platform)
4. [Gestión de Credenciales OAuth 2.0](#4-gestión-de-credenciales-oauth-20)
5. [Obtención y Registro de Huellas SHA-1 y SHA-256 en Windows](#5-obtención-y-registro-de-huellas-sha-1-y-sha-256-en-windows)
6. [Configuraciones en el Código Fuente y Manifiestos de Android](#6-configuraciones-en-el-código-fuente-y-manifiestos-de-android)
7. [Protocolo de Pruebas y Validación](#7-protocolo-de-pruebas-y-validación)
8. [Diagnóstico y Solución de Errores Frecuentes](#8-diagnóstico-y-solución-de-errores-frecuentes)
9. [Defensa y Justificación Técnica para la Exposición Académica](#9-defensa-y-justificación-técnica-para-la-exposición-académica)

---

## 1. Proyecto de Google Cloud y Vinculación con Firebase

### 1.1. ¿Crear un nuevo proyecto o reutilizar el existente?
**Decisión Técnica Recomendada: REUTILIZAR EL PROYECTO EXISTENTE DE FIREBASE.**

Todo proyecto creado en **Firebase Console** es, a nivel de infraestructura, un proyecto de **Google Cloud Platform (GCP)**. 
- Reutilizar el mismo proyecto garantiza que las credenciales de Android (`google-services.json`), el identificador del paquete (`com.example.flutter_application_1` o similar), las huellas SHA-1 y el cliente OAuth 2.0 Web compartan el mismo espacio de nombres y certificados criptográficos.
- Crear un proyecto nuevo e independiente requeriría duplicar huellas digitales, gestionar dos consolas separadas y causaría conflictos en la firma de tokens de Google Sign-In.

### 1.2. Cómo acceder a Google Cloud Console
1. Ingresa a [https://console.cloud.google.com/](https://console.cloud.google.com/) con la misma cuenta de Google utilizada para administrar Firebase.
2. En la barra superior, pulsa sobre el desplegable de selección de proyectos.
3. Selecciona el proyecto de **VendiX** (fácilmente identificable por el ID que aparece en tu archivo `android/app/google-services.json`, en el campo `"project_id"`, por ejemplo: `vendix-...` o `flutter-application-1-...`).

---

## 2. Habilitación de Google Drive API v3

Para que la aplicación móvil pueda comunicarse con los servidores de Google Drive y subir los reportes, la API debe estar encendida en la biblioteca de Google Cloud.

### 2.1. Pasos para la habilitación:
1. En Google Cloud Console, abre el menú de navegación lateral (icono de tres líneas horizontales en la esquina superior izquierda).
2. Dirígete a **APIs y servicios** > **Biblioteca** (o ingresa directamente a [https://console.cloud.google.com/apis/library](https://console.cloud.google.com/apis/library)).
3. En el buscador central, escribe: `Google Drive API`.
4. Selecciona el resultado oficial denominado **Google Drive API** (desarrollado por Google).
5. Pulsa el botón azul **HABILITAR** (*ENABLE*).
6. Una vez habilitada, la consola te redirigirá al panel de métricas de la API.

### 2.2. ¿Debe habilitarse Google Sheets API?
**NO.** En la nueva arquitectura de VendiX, **Google Sheets API debe permanecer DESHABILITADA**.
- **Justificación:** Los datos, encabezados, tablas y formatos son generados íntegramente por el motor local en formato `.xlsx`. Cuando Google Drive API recibe la solicitud de subida multipart con el parámetro `"mimeType": "application/vnd.google-apps.spreadsheet"`, el propio motor de Google Drive realiza la conversión interna a Google Sheets sin necesidad de invocar endpoints de Sheets API v4. Esto simplifica los permisos y reduce la superficie de ataque.

### 2.3. Cuotas y Costos de Google Drive API
- **Costo:** 100% Gratuito dentro de los límites de uso estándar.
- **Cuota:** Google otorga 20,000 consultas cada 100 segundos y miles de peticiones diarias sin costo alguno, lo cual excede por órdenes de magnitud las necesidades académicas y comerciales de prueba de VendiX.

---

## 3. Configuración de la Pantalla de Consentimiento OAuth (Google Auth Platform)

Cuando un usuario pulsa "Exportar a Google Sheets", Google le muestra una pantalla preguntándole si autoriza a VendiX a crear archivos. Esta pantalla se configura en el módulo de consentimiento OAuth.

### 3.1. Acceso a la configuración:
1. En el menú lateral, ve a **APIs y servicios** > **Pantalla de consentimiento de OAuth** (o [https://console.cloud.google.com/apis/credentials/consent](https://console.cloud.google.com/apis/credentials/consent)).

### 3.2. Selección de Tipo de Usuario (User Type):
- Selecciona **Externo** (*External*), ya que permite la conexión de cualquier usuario con cuenta `@gmail.com` fuera de una organización de Google Workspace. Pulsa **CREAR**.

### 3.3. Datos de la Aplicación (Paso 1):
- **Nombre de la aplicación:** `VendiX`
- **Correo electrónico de asistencia del usuario:** Selecciona tu correo personal/administrador.
- **Logotipo de la aplicación:** Opcional (puedes omitirlo durante desarrollo).
- **Datos de contacto del desarrollador:** Ingresa tu correo electrónico.
- Pulsa **GUARDAR Y CONTINUAR**.

### 3.4. Permisos y Scopes (Paso 2):
1. Pulsa el botón **AGREGAR O QUITAR PERMISOS** (*ADD OR REMOVE SCOPES*).
2. En la ventana emergente, busca y marca el scope:
   ```text
   https://www.googleapis.com/auth/drive.file
   ```
   *Descripción: Ver, crear y editar solo los archivos de Google Drive que hayas usado o abierto con esta aplicación.*
3. **¿Por qué este scope y no `drive` completo?**
   - El scope general `https://www.googleapis.com/auth/drive` es considerado **restringido/sensible** por Google y exige un proceso de auditoría y verificación por video de semanas.
   - En contraste, `https://www.googleapis.com/auth/drive.file` es un scope de **acceso no invasivo**: solo permite a VendiX ver y modificar los archivos que la propia aplicación ha creado. No puede leer fotos, documentos personales ni carpetas privadas del usuario. Es el scope recomendado por Google y no bloquea el uso en pruebas.
4. Pulsa **ACTUALIZAR** y luego **GUARDAR Y CONTINUAR**.

### 3.5. Usuarios de Prueba (Test Users - Paso 3 - ¡MUY CRÍTICO!):
> [!IMPORTANT]
> **REQUISITO INDISPENSABLE DURANTE ETAPA DE DESARROLLO:**  
> Mientras la aplicación se encuentra en estado de publicación **En pruebas** (*Testing*), Google bloqueará con el error `access_denied` (*"Esta app está bloqueada"*) a cualquier correo que no haya sido añadido como usuario de prueba.
> 
> 1. En la sección **Usuarios de prueba**, pulsa **+ ADD USERS**.
> 2. Escribe tu correo de desarrollador y los correos `@gmail.com` de tus compañeros de equipo que van a probar la aplicación.
> 3. Pulsa **GUARDAR**.

---

## 4. Gestión de Credenciales OAuth 2.0

En **APIs y servicios** > **Credenciales**, debes verificar que existan dos tipos de clientes:

### 4.1. Cliente de Aplicación Web (Web Client ID):
- Firebase crea automáticamente un cliente denominado `Web client (auto created by Google Service)`.
- Su ID tiene el formato:
  `1072094421175-b9pe80lgr9r5g33oao2jb697po91plbq.apps.googleusercontent.com`
- Este identificador ya está configurado en `DriveAuthorizationService` y `GoogleAuthService`. **No debes modificarlo ni borrarlo.**

### 4.2. Cliente de Android (Android Client ID):
- Debe existir un cliente de tipo **Android** que vincule el nombre de paquete de tu aplicación con la huella digital SHA-1 de tu máquina.

---

## 5. Obtención y Registro de Huellas SHA-1 y SHA-256 en Windows

Google Play Services valida que las peticiones provengan de un APK firmado legítimamente comparando la huella SHA-1 del certificado de Android. Si la huella no está registrada en Firebase, Google Sign-In arroja el error `DEVELOPER_ERROR` (código `10`).

### 5.1. Cómo obtener la huella SHA-1 de depuración en Windows:
Abre una terminal de PowerShell dentro de la carpeta del proyecto y ejecuta:

```powershell
cd android
./gradlew signingReport
```

En la salida de la consola, localiza la sección correspondiente a la variante `debug`:
```text
Variant: debug
Config: debug
Store: C:\Users\crist\.android\debug.keystore
Alias: AndroidDebugKey
SHA1: 4A:72:B1:... (40 caracteres hexadecimales)
SHA-256: 8F:93:... (64 caracteres hexadecimales)
```

### 5.2. Cómo registrar las huellas en Firebase Console:
1. Ingresa a [https://console.firebase.google.com/](https://console.firebase.google.com/).
2. Selecciona tu proyecto VendiX y pulsa sobre el engranaje de **Configuración del proyecto** (esquina superior izquierda).
3. En la pestaña **General**, baja hasta la sección **Tus apps** y selecciona la app de Android.
4. En el apartado **Certificados de huellas digitales SHA**, pulsa **Agregar huella digital**.
5. Pega el valor de tu **SHA-1** y guarda.
6. Pulsa nuevamente **Agregar huella digital**, pega el valor de tu **SHA-256** y guarda.
7. Descarga el archivo `google-services.json` actualizado y reemplázalo en `android/app/google-services.json`.

---

## 6. Configuraciones en el Código Fuente y Manifiestos de Android

### 6.1. Lo que Antigravity configuró automáticamente en el código:
- **`lib/services/reports/drive_authorization_service.dart`**: Implementó la solicitud limpia del scope `https://www.googleapis.com/auth/drive.file` usando `GoogleSignIn.instance.authorizationClient.authorizationHeaders`.
- **`lib/services/reports/google_drive_service.dart`**: Implementó la llamada HTTP `multipart/related` contra `https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart` solicitando conversión nativa a `application/vnd.google-apps.spreadsheet`.
- **`lib/services/reports/excel_report_service.dart`**: Integró la codificación binaria de libros Excel y la compartición nativa mediante `SharePlus`.
- **`android/app/src/main/AndroidManifest.xml`**: Se incorporó el bloque `<queries>` para permitir que `url_launcher` abra enlaces `https://` en el navegador del teléfono.
- **`pubspec.yaml`**: Se registraron las dependencias `excel: ^4.0.6`, `path_provider`, `share_plus` y `url_launcher`.

### 6.2. Lo que el desarrollador debe verificar manualmente:
1. Comprobar que en Google Cloud Console la API de Google Drive figure como **Habilitada**.
2. Asegurar que los correos que probarán la exportación a Drive estén agregados en la lista de **Usuarios de prueba** de la pantalla de consentimiento.

---

## 7. Protocolo de Pruebas y Validación

Para comprobar que la arquitectura funciona de forma 100% aislada:

### Prueba A: Descarga Local de Excel (Sin Cuenta de Google)
1. Inicia sesión en VendiX con cualquier correo (incluso Hotmail, Yahoo o usuario de prueba).
2. Ve al panel de opciones y pulsa **Exportar reportes comerciales**.
3. Selecciona **Descargar archivo Excel (.XLSX)**.
4. **Resultado esperado:** La app genera el archivo localmente y abre el menú de compartir de Android (permitiendo enviar por WhatsApp, guardar en descargas o abrir en Excel móvil). **En ningún momento debe pedir cuenta de Google ni permisos de Drive**.

### Prueba B: Exportar a Google Sheets (Subida a Drive)
1. Pulsa **Exportar a Google Sheets (Drive)**.
2. La app solicitará autorización de Google. Puedes elegir cualquier cuenta `@gmail.com` registrada como usuario de prueba.
3. Al autorizar, la app sube el archivo y muestra el diálogo de éxito con el nombre del archivo.
4. Pulsa **Abrir Hoja de Cálculo**.
5. **Resultado esperado:** Se abre Google Sheets en el navegador o en la app móvil. El documento está en tu propio Drive personal, con todas las pestañas estructuradas, formatos monetarios y privado para ti.

### Prueba C: Cancelación de OAuth
1. Pulsa **Exportar a Google Sheets (Drive)**.
2. Cuando aparezca la ventana de selección de cuenta de Google, pulsa hacia atrás o fuera de la ventana para cancelar.
3. **Resultado esperado:** La aplicación muestra un aviso amable (*"Autorización cancelada"*), **NO se cierra la sesión de VendiX** y el usuario puede continuar operando normalmente o descargar el Excel local.

---

## 8. Diagnóstico y Solución de Errores Frecuentes

| Error / Código | Causa Raíz | Solución Paso a Paso |
|---|---|---|
| **`access_denied` / "Esta app está bloqueada"** | La app está en modo "Testing" y el correo que intenta autorizar no está en la lista de prueba. | Entra a Google Cloud Console > Pantalla de consentimiento de OAuth > Usuarios de prueba > Agrega el correo `@gmail.com` de la persona. |
| **`DEVELOPER_ERROR` [10]** | La huella SHA-1 del APK no coincide con la registrada en Firebase Console. | Ejecuta `./gradlew signingReport`, copia la huella SHA-1 de la variante `debug` y pégala en la configuración de la app en Firebase Console. |
| **HTTP 403: "Drive API not enabled"** | La API de Google Drive está apagada en el proyecto de Google Cloud. | Ve a APIs y servicios > Biblioteca > Busca "Google Drive API" > Pulsa "Habilitar". |
| **HTTP 401: Unauthorized** | El Access Token expiró o el usuario revocó el acceso. | La aplicación limpia automáticamente el token en memoria para que el siguiente clic solicite un token nuevo. |
| **HTTP 403: "Insufficient Permission"** | El scope solicitado no incluye permisos de escritura. | Verifica que en `DriveAuthorizationService` el scope sea exactamente `https://www.googleapis.com/auth/drive.file`. |

---

## 9. Defensa y Justificación Técnica para la Exposición Académica

Si el docente o evaluador consulta sobre las decisiones técnicas de esta integración, estas son las respuestas formales:

### Pregunta 1: ¿Por qué utilizaron Google Drive API v3 y no Google Sheets API v4?
> *"Decidimos no utilizar Google Sheets API directamente porque requería enviar cientos de peticiones celda por celda o estructuras JSON voluminosas por la red, además de obligar al usuario a tener cuenta Google para cualquier reporte. En su lugar, adoptamos una arquitectura desacoplada: generamos el archivo físico Excel (.XLSX) con tablas, estilos y formatos de manera 100% local en el dispositivo. Luego, utilizamos Google Drive API v3 enviando una solicitud multipart donde indicamos que el MIME type destino es una hoja de cálculo (`application/vnd.google-apps.spreadsheet`). Google Drive realiza la conversión nativa en sus servidores de forma transparente, limpia y privada."*

### Pregunta 2: ¿Cómo se comunica Flutter con Google Drive API?
> *"La comunicación se realiza mediante una petición HTTP POST directa al endpoint REST oficial de Google: `https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart`. La petición utiliza una cabecera `multipart/related` delimitada por boundaries, dividida en dos secciones: la primera sección envía los metadatos en formato JSON (`name` y `mimeType`), y la segunda sección envía los bytes binarios del archivo XLSX. El servidor responde con código 200 OK devolviendo el `id` y el `webViewLink` del documento creado."*

### Pregunta 3: ¿Por qué la autenticación de VendiX es independiente de la autorización de Drive?
> *"Para cumplir con el principio de responsabilidad única y no discriminar a los usuarios por su proveedor de correo. Un administrador puede registrarse en VendiX con su correo corporativo o de Hotmail. Si solo quiere descargar su reporte en Excel para verlo en su computadora, lo hace sin necesidad de Google. Si desea sincronizarlo en la nube, autoriza de forma puntual su cuenta personal de Google Drive. Esta separación garantiza que revocar permisos en Google jamás destruya la sesión activa de Firebase."*
