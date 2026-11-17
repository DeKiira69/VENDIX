# Resumen Técnico Directo: Cambios Clave en Vendix

---

## 1. Evolución de Roles y Autenticación

| Fase | Cómo funcionaba | Problema | Solución actual |
|---|---|---|---|
| **Fase 1 (Inicial)** | 3 botones al inicio: *Cliente*, *Secretario*, *Emprendedor*. | Un secretario se registraba solo, sin pertenecer a ninguna tienda ni tener dueño que lo apruebe. | Se eliminó el botón de secretario independiente. |
| **Fase 2 (Intermedia)** | 2 registros: *Cliente* y *Emprendedor*. El cliente enviaba solicitud de empleo. | Al registrarse como cliente, la app lo bloqueaba exigiendo un código de Live. Quien solo quería trabajar no podía postularse. | Se creó el Hub de Bienvenida sin bloqueos. |
| **Fase 3 (Actual)** | Hub de bienvenida con 2 tarjetas: **Asociarse a tienda** o **Solicitar empleo**. | Ninguno. Flujo libre y desacoplado. | • El usuario se postula a secretario sin haber comprado nada.<br>• El cliente puede salir de una tienda y vincularse a otra.<br>• El secretario puede **renunciar a una tienda específica** desde su perfil sin perder su cuenta ni otros empleos. |

---

## 2. Asistente con Gemini AI (Chatbot RAG)

* **Archivos clave:**
  * [lib/services/gemini_service.dart](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/services/gemini_service.dart) (Lógica e integración con Gemini API).
  * [lib/screens/client/widgets/client_chatbot_sheet.dart](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/screens/client/widgets/client_chatbot_sheet.dart) (Botón flotante e interfaz de chat).

* **¿Por qué está SOLO en el rol Cliente?**
  * La **clienta** necesita autoservicio las 24 horas (saber su deuda, stock de ropa, cómo apartar en el live).
  * El **emprendedor y el secretario** ya tienen tablas de métricas y paneles de control; un chatbot en sus pantallas los distraería durante la venta en vivo.

* **Parámetros reales que lee de Firestore (RAG):**
  * **De la clienta (`usuarios`):** `nombre`, `saldoPendiente`, `totalComprado`, `totalPagado`, prendas apartadas.
  * **Del emprendimiento (`Administradores`):** `nombreEmprendimiento`, nombre y apellido del dueño, `telefono`, `correo`, dirección física de la tienda.
  * **Del catálogo (`prendas`):** `nombre`, `precio`, `talla`, `color`, `stock` real disponible.

* **Respuestas que entrega:**
  1. Consulta de saldo y abonos pendientes.
  2. Disponibilidad de prendas con precios y tallas reales.
  3. Quién es el dueño y datos de contacto de la tienda.
  4. Dirección física del local.
  5. Instrucciones paso a paso para apartar prendas en las transmisiones en vivo.
  * *Seguridad:* Filtros estrictos. No expone contraseñas, tokens ni información de otros clientes.

---

## 3. Geolocalización en Tiempo Real

* **Archivo clave:** [lib/widgets/store_location_map.dart](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/widgets/store_location_map.dart).
* **Tecnologías:** `mapbox_maps_flutter` y GPS nativo.
* **Funcionamiento:**
  * Detecta la ubicación geográfica del usuario en tiempo real vía satélite GPS.
  * Muestra la tienda física del emprendedor con marcadores interactivos en el mapa.
  * Permite calcular cercanía y rutas para que la clienta retire sus prendas compradas en el live o coordine la entrega.

---

## 4. Base de Datos Aislada (Multitenancy sin datos mezclados)

* **Problema anterior:**
  * Existían datos de prueba quemados en código.
  * Las prendas y saldos no estaban estrictamente segmentados y se cruzaban entre tiendas.

* **Solución actual:**
  * **Llave `adminId`:** Cada tienda opera como un inquilino independiente (*Multitenancy*).
  * **Prendas:** Filtradas con `where adminId == ...`. Una tienda no puede ver prendas de otra.
  * **Secretarios:** Guardados con ID compuesto `${uid}_${adminId}`. Un usuario puede trabajar en varias tiendas con historiales completamente separados.
  * **Cero datos basura:** La app consume 100% datos vivos autenticados de Cloud Firestore.
