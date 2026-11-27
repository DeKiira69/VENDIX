# Documentación Técnica: Integración de API QR (QuickChart) en VendiX

## 1. Nombre de la API y proveedor
- **API:** QuickChart QR Code API
- **Proveedor:** QuickChart (`quickchart.io`)

## 2. Enlace a su documentación oficial
- Documentación oficial de códigos QR: https://quickchart.io/documentation/qr-codes/

## 3. Endpoint utilizado
- **Método:** `GET`
- **URL base:** `https://quickchart.io/qr`
- **Construcción en VendiX:** [`InvitationCodeService.construirUrlQrQuickChart`](../lib/services/invitation_code_service.dart)
- **Ejemplo de petición generada:**
  ```text
  https://quickchart.io/qr?text=ABC-234&size=500&ecLevel=H&margin=2&dark=241B35&light=FFFFFF&format=png
  ```

## 4. Qué información recibe y qué devuelve
- **Parámetros enviados (Query String):**
  - `text`: El código de invitación del emprendimiento almacenado en Firebase (por ejemplo, `ABC-234`).
  - `size`: `500` (resolución de 500x500 px para nitidez en pantallas de alta densidad).
  - `ecLevel`: `H` (nivel de corrección de errores alto, ~30% de recuperación ante oclusión).
  - `margin`: `2` (zona silenciosa limpia alrededor de la matriz QR).
  - `dark`: `241B35` (color oscuro corporativo de VendiX para máximo contraste).
  - `light`: `FFFFFF` (fondo blanco sólido para facilitar la lectura óptica).
  - `format`: `png` (imagen raster lista para renderizarse con `Image.network`).
- **Respuesta recibida:**
  - Código HTTP `200 OK`
  - `Content-Type: image/png`
  - Flujo binario de imagen PNG del código QR listo para mostrarse en pantalla.

## 5. Por qué se eligió frente a una librería local de Flutter
1. **Cero incremento en el tamaño del APK ni dependencias nativas:** No requiere añadir paquetes externos adicionales a `pubspec.yaml` ni recompilar plugins nativos.
2. **Renderizado uniforme y parametrizable por URL:** Permite controlar tamaño, margen, colores hexadecimales y nivel de corrección de errores `ecLevel=H` mediante una URL estándar HTTPS consumida directamente por `Image.network`.
3. **Desacoplamiento limpio:** QuickChart actúa únicamente como motor de renderizado gráfico; toda la lógica de negocio permanece en Flutter y Firebase.

## 6. Condiciones y límites de su modalidad gratuita
Según la documentación pública verificada de QuickChart:
- **Plan Community / Gratuito (`$0/mes`):**
  - Permite generar códigos QR estáticos bajo demanda mediante `GET https://quickchart.io/qr` sin expiración y con escaneos ilimitados.
  - Aplica límites de tasa (rate limits) en el servicio público gratuito (por ejemplo, límites por IP por minuto para evitar abuso automatizado). Para el uso real de VendiX (mostrar el QR del emprendimiento bajo demanda en pantalla), el volumen de peticiones es mínimo y se mantiene ampliamente dentro del uso gratuito.
  - *Nota de transparencia:* Los límites numéricos exactos por IP pueden variar según la infraestructura vigente de QuickChart; se verificó mediante petición real (`HTTP 200 OK`, `image/png`) que el endpoint público responde sin restricciones de pago.

## 7. Confirmación de clave, registro, tarjeta bancaria o suscripción
- **Requiere API Key:** **No**
- **Requiere registro de cuenta:** **No**
- **Requiere tarjeta bancaria:** **No**
- **Requiere suscripción de pago:** **No**

## 8. Cómo se incorpora el logo de VendiX al QR
En [`StoreQrDialog`](../lib/widgets/qr/store_qr_dialog.dart):
1. **Logo central moderado:** Sobre la imagen PNG devuelta por QuickChart se superpone el widget nativo [`VendixLogo`](../lib/widgets/vendix_logo.dart) (`size: 40`, estático) dentro de un contenedor blanco redondeado con sombra suave (`padding: 5`). Gracias al parámetro `ecLevel=H` (30% de tolerancia a errores), el área central cubierta (~18–20%) no impide que cualquier cámara o lector QR decodifique el código.
2. **Marca de agua tenue en la tarjeta:** En el fondo del diálogo (`Stack` detrás del contenido) se coloca `VendixLogo` con opacidad muy baja (`0.045` y `0.035`), completamente fuera de la zona blanca del QR para no interferir jamás con el contraste ni la lectura.
3. **Código en texto copiable:** Debajo del QR se muestra el código de invitación en texto grande con botón de copiado manual al portapapeles.

## 9. Qué parte del proceso sigue siendo responsabilidad de Firebase y de VendiX
QuickChart **no** crea, almacena ni valida códigos de invitación. Todo el ciclo de vida pertenece a VendiX y Cloud Firestore:
- **Generación y propiedad (solo Administrador/Emprendedor):** [`InvitationCodeService.obtenerOGenerarCodigoAdmin`](../lib/services/invitation_code_service.dart) consulta primero `Administradores/{adminId}` y documentos previos de `secretarios` para reutilizar el código existente sin duplicarlo; solo si no existe ninguno, genera uno nuevo (`XXX-999`) y lo persiste en `Administradores`, `usuarios` y `secretarios`.
- **Consulta de solo lectura (Secretario):** En [`MoreScreen`](../lib/screens/secretary/more_screen.dart), el secretario únicamente puede visualizar y copiar el código del administrador, sin botones para generar ni reemplazarlo.
- **Asociación y validación del cliente:** [`EnterCodeScreen`](../lib/screens/client/enter_code_screen.dart) conserva intacta la validación contra Cloud Firestore (`secretarios` y respaldo en `Administradores`) y el guardado multi-tienda en `usuarios/{uid}/mis_tiendas`. Además, admite el parámetro opcional `codigoInicial` para prellenar el campo automáticamente.

## 10. Pruebas realizadas y configuración pendiente para enlaces profundos (App Links)
- **Pruebas realizadas:**
  - Verificación directa del endpoint `https://quickchart.io/qr?text=VENDIX-TEST&size=300&ecLevel=H&margin=2` obteniendo respuesta `HTTP/1.1 200 OK`, `Content-Type: image/png` (3,445 bytes).
  - Verificación estática con `flutter analyze` sobre todo el proyecto tras integrar los cambios.
  - Verificación de código en `StoreQrDialog`, `AdminMoreScreen`, `MoreScreen` (secretario) y `EnterCodeScreen`:
    - El QR consulta el código existente del administrador sin regenerarlo al abrir el diálogo.
    - El secretario no tiene controles de generación/regeneración.
    - La pantalla del secretario agrupa las tres opciones secundarias en una lista desplegable contraída por defecto, manteniendo `Cerrar sesión` visible sin desplazamiento vertical innecesario.
  - *Nota:* Las pruebas de escaneo físico con cámara de teléfono deben ejecutarse directamente sobre la app compilada en dispositivo real (`flutter run` / APK) para validar el enfoque óptico en la pantalla del usuario.
- **Estado actual de Deep Links / Android App Links:**
  - Se comprobó en `android/app/src/main/AndroidManifest.xml` y `lib/main.dart` que el proyecto **no tiene configurados** actualmente Android App Links ni un manejador de enlaces profundos (`app_links` / `onGenerateRoute`).
  - **Configuración adicional necesaria para abrir VendiX automáticamente desde la cámara externa:**
    1. Contar con un dominio HTTPS propio (por ejemplo, `https://tudominio.com`) y alojar el archivo `/.well-known/assetlinks.json` con el `package_name` y la huella SHA-256 de firma de la app.
    2. Añadir el `<intent-filter android:autoVerify="true">` en `android/app/src/main/AndroidManifest.xml` apuntando a ese dominio y ruta (o un esquema personalizado como `vendix://asociar`).
    3. Agregar un paquete de escucha de enlaces en Flutter (como `app_links`) en `pubspec.yaml` y enrutar el parámetro `codigo` hacia `EnterCodeScreen(codigoInicial: codigo)`.
