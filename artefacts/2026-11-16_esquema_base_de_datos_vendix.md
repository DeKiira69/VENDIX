# Arquitectura y Esquema de Base de Datos — VENDIX
**Motor:** Google Cloud Firestore (NoSQL Document Store)  
**Proyecto:** VENDIX Live Commerce Management  
**Fecha de Generación:** 16 de noviembre de 2026  

---

## 1. Visión General del Modelo de Datos

VENDIX utiliza **Cloud Firestore** estructurado bajo un esquema de **colecciones raíz altamente desnormalizadas y optimizadas para lectura en tiempo real** a través de `StreamBuilder`. 

A diferencia de un modelo relacional tradicional (SQL), Firestore utiliza identificadores de documentos vinculados (`foreign keys` lógicas almacenadas como strings: `adminId`, `clienteId`, `secretarioId`, `prendaId`, `compraId`) para garantizar:
1. **Segregación multi-inquilino (Multi-tenant):** Cada emprendedor (`Administradores`) tiene su propio inventario (`prendas`), su equipo de trabajo (`secretarios`), sus clientes vinculados (`clientes`) y sus transacciones (`compras` y `pagos`).
2. **Consultas ultrarrápidas (<15ms):** Filtradas por índices compuestos (ej. `where('adminId', isEqualTo: ...)` y `orderBy('fecha', descending: true)`).
3. **Escalabilidad reactiva:** Notificaciones instantáneas de compras y actualización de saldos durante transmisiones en vivo (TikTok / Instagram / Facebook Live).

---

## 2. Diagrama Entidad-Relación (ERD)

```mermaid
erDiagram
    usuarios ||--o| Administradores : "extiende si rol = admin"
    usuarios ||--o{ clientes : "vinculado a tienda vía"
    usuarios ||--o{ secretarios : "postula/trabaja como"
    usuarios ||--o| fotos_perfil : "almacena foto CDN"

    Administradores ||--o{ prendas : "es dueño de (adminId)"
    Administradores ||--o{ secretarios : "emplea/supervisa (adminId)"
    Administradores ||--o{ clientes : "atiende en su tienda (adminId)"
    Administradores ||--o{ compras : "factura en sus lives (adminId)"
    Administradores ||--o{ pagos : "recibe abonos (adminId)"

    secretarios ||--o{ clientes : "vincula por codigoLive (secretarioId)"
    secretarios ||--o{ compras : "registra pedidos en vivo (secretarioId)"
    secretarios ||--o{ pagos : "registra cobros/abonos (secretarioId)"

    clientes ||--o{ compras : "adquiere prendas (clienteId)"
    clientes ||--o{ pagos : "abona saldo deudor (clienteId)"

    prendas ||--o{ compras : "es vendida en (prendaId)"

    usuarios {
        string uid PK "ID de Firebase Auth"
        string nombre "Nombre de pila"
        string apellido "Apellido"
        string correo "Email de autenticacion"
        string telefono "Numero de contacto"
        string rol "cliente | admin | secretaria"
        string direccion "Ubicacion fisica opcional"
        string fotoUrl "URL avatar Google o Cloudinary"
        string metodo_registro "email_password | google"
        timestamp fecha_registro "Fecha de creacion"
        boolean activo "Estado de cuenta"
    }

    Administradores {
        string id PK "Coincide con uid del admin"
        string nombre "Nombre del emprendedor"
        string apellido "Apellido del emprendedor"
        string correo "Email corporativo/contacto"
        string telefono "Telefono de contacto"
        string nombreEmprendimiento "Nombre comercial de la tienda"
        string ubicacion_tienda "Direccion fisica del local"
        double latitud "Coordenada Mapbox lat"
        double longitud "Coordenada Mapbox lng"
        boolean estado "true = activo | false = suspendido"
        timestamp fecha_registro "Fecha de alta"
    }

    secretarios {
        string id PK "uid o compuesto {uid}_{adminId}"
        string uid FK "uid del usuario en usuarios"
        string clienteId FK "uid original del cliente"
        string adminId FK "ID del emprendedor titular"
        string adminNombre "Nombre del titular"
        string nombre "Nombre completo del secretario"
        string correo "Correo del secretario"
        string telefono "Telefono del secretario"
        string nombreEmprendimiento "Tienda a la que pertenece"
        string codigoLive UK "Codigo unico de 6 caracteres (ej. HCC-929)"
        string estado_solicitud "pendiente | aprobado | rechazado"
        boolean aprobado "true = habilitado para operar"
        boolean estado "true = activo laboralmente"
        timestamp fecha_solicitud "Momento de postulacion"
        timestamp fecha_registro "Momento de aprobacion"
    }

    clientes {
        string id PK "uid del cliente o autogenerado"
        string uid FK "uid del usuario en Firebase Auth"
        string adminId FK "Emprendedor al que pertenece"
        string secretarioId FK "Secretario que lo registro"
        string codigoLive "Codigo del live con el que se vinculo"
        string nombre "Nombre completo"
        string correo "Email del cliente"
        string telefono "Numero WhatsApp para entregas"
        string direccion "Direccion de envio"
        string fotoUrl "Foto de perfil"
        double saldoPendiente "Monto acumulado por pagar"
        double totalCompras "Historico de compras"
        double totalPagado "Historico de abonos"
        string metodo_registro "google | manual_secretario"
        timestamp creadoEn "Momento de creacion"
    }

    prendas {
        string id PK "Autogenerado Firestore"
        string adminId FK "Emprendedor dueno de la prenda"
        string nombre "Descripcion de la prenda"
        string tipo "Vestido, Blusa, Pantalon, etc."
        string color "Color principal"
        string talla "XS, S, M, L, XL, etc."
        string codigoPrenda "Codigo de identificacion o barra"
        double precio "Precio de venta al publico"
        int stock "Unidades disponibles"
        string imagenUrl "Foto en Cloudinary / CDN"
        boolean disponible "true = disponible para venta"
        timestamp fecha_creacion "Fecha de ingreso"
    }

    compras {
        string id PK "Autogenerado Firestore"
        string adminId FK "Emprendedor dueno de la venta"
        string clienteId FK "Cliente que compro"
        string prendaId FK "Prenda seleccionada"
        string secretarioId FK "Operador que registro el pedido"
        string nombreCliente "Nombre desnormalizado para consultas"
        string nombrePrenda "Nombre de la prenda al comprar"
        double precio "Precio pactado en el momento"
        int cantidad "Unidades compradas"
        double subtotal "precio x cantidad"
        string estado "pendiente | entregado | cancelado"
        string tipoEnvio "retiro_local | delivery"
        timestamp fecha "Fecha y hora del pedido en vivo"
    }

    pagos {
        string id PK "Autogenerado Firestore"
        string adminId FK "Emprendedor destinatario"
        string clienteId FK "Cliente que realiza el abono"
        string compraId FK "Compra asociada (opcional)"
        string secretarioId FK "Secretario que cobra"
        string clienteNombre "Nombre desnormalizado"
        double monto "Cantidad abonada en dolares"
        string metodoPago "Efectivo | Transferencia | DeUna"
        string comprobanteUrl "Captura del comprobante (Cloudinary)"
        string notas "Observaciones o numero de referencia"
        timestamp fecha "Fecha y hora de registro del abono"
    }

    fotos_perfil {
        string id PK "uid del usuario"
        string uid FK "Referencia a usuarios"
        string url "URL publica en Cloudinary CDN"
        string publicId "Identificador unico de Cloudinary"
        timestamp actualizadoEn "Fecha de ultima subida"
    }
```

---

## 3. Diccionario de Datos por Colección

### 3.1. `usuarios` (Autenticación y Perfil Base)
Es la colección central de autenticación de la aplicación, vinculada directamente con **Firebase Authentication** (`doc.id == User.uid`).

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `uid` | `String` | **Sí** | Identificador único emitido por Firebase Auth. |
| `nombre` | `String` | **Sí** | Nombre del usuario (capturado en login o Google). |
| `apellido` | `String` | No | Apellido del usuario. |
| `correo` | `String` | **Sí** | Correo electrónico en minúsculas. |
| `telefono` | `String` | No | Número telefónico de contacto. |
| `rol` | `String` | **Sí** | Rol del sistema: `'cliente'`, `'administrador'`, `'secretario'` / `'secretaria'`. |
| `direccion` | `String` | No | Domicilio o sector de residencia. |
| `fotoUrl` | `String` | No | Enlace a la imagen en Cloudinary o Google avatar. |
| `metodo_registro`| `String` | No | `'google'` o `'email_password'`. |
| `activo` | `Boolean`| **Sí** | Bandera de acceso general a la plataforma (`true`). |
| `fecha_registro` | `Timestamp` | **Sí** | Marca de tiempo de registro (`serverTimestamp`). |

---

### 3.2. `Administradores` (Tiendas / Emprendedores)
Contiene la información de cada negocio y su dueño. La llave del documento es el `uid` del usuario administrador.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `id` / `doc.id` | `String` | **Sí** | Coincide con el `uid` del usuario. |
| `nombre` | `String` | **Sí** | Nombre del dueño del negocio. |
| `apellido` | `String` | No | Apellido del dueño. |
| `correo` | `String` | **Sí** | Correo oficial del emprendimiento. |
| `telefono` | `String` | No | Teléfono de WhatsApp para pedidos. |
| `nombreEmprendimiento`| `String` | **Sí** | Nombre comercial de la tienda (ej. *"Ojo de Fantasma"*). |
| `ubicacion_tienda` | `String` | No | Dirección escrita seleccionada en Mapbox. |
| `latitud` | `Double` | No | Latitud geográfica del local. |
| `longitud` | `Double` | No | Longitud geográfica del local. |
| `estado` | `Boolean`| **Sí** | `true` si la tienda está habilitada. |
| `fecha_registro` | `Timestamp` | **Sí** | Fecha de apertura de la tienda en VENDIX. |

---

### 3.3. `secretarios` (Equipo Operativo & Solicitudes de Empleo)
Permite a los usuarios operar transmisiones en vivo y tomar pedidos en nombre de un emprendedor. También gestiona el flujo de postulaciones laborales.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `doc.id` | `String` | **Sí** | Puede ser `uid` o compuesto `${clienteId}_${adminId}`. |
| `uid` / `clienteId` | `String` | **Sí** | `uid` del usuario que trabaja o postula. |
| `adminId` | `String` | **Sí** | `uid` del emprendedor al que asiste. |
| `adminNombre` | `String` | No | Nombre del dueño del negocio (desnormalizado). |
| `nombre` | `String` | **Sí** | Nombre completo del secretario(a). |
| `correo` | `String` | **Sí** | Correo electrónico de acceso. |
| `telefono` | `String` | No | Teléfono de contacto. |
| `nombreEmprendimiento`| `String` | No | Nombre del negocio donde labora. |
| `codigoLive` | `String` | No | **Código único de 6 caracteres** (ej. `HCC-929`) con el que los clientes se unen a su live. |
| `estado_solicitud` | `String` | **Sí** | `'pendiente'`, `'aprobado'`, `'rechazado'`. |
| `aprobado` | `Boolean`| **Sí** | `true` permite acceder al panel `SecretaryShell`. |
| `estado` | `Boolean`| **Sí** | Estado laboral activo/inactivo. |
| `fecha_solicitud` | `Timestamp` | **Sí** | Momento exacto de envío de postulación. |

---

### 3.4. `clientes` (Fichas de Compradores en Tiendas)
Almacena el registro de cada cliente vinculado a un negocio o creado durante un Live.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `doc.id` | `String` | **Sí** | `uid` del cliente o ID autogenerado. |
| `uid` | `String` | No | `uid` de autenticación si el cliente descargó la app. |
| `adminId` | `String` | **Sí** | ID del emprendimiento que lo atiende. |
| `secretarioId` | `String` | No | Secretario que lo enroló durante el Live. |
| `codigoLive` | `String` | No | Código con el cual se enlazó a la tienda. |
| `nombre` | `String` | **Sí** | Nombre completo de la clienta / cliente. |
| `correo` | `String` | No | Correo electrónico. |
| `telefono` | `String` | No | Celular de contacto para despachos. |
| `direccion` | `String` | No | Dirección domiciliaria de entrega. |
| `saldoPendiente` | `Double` | **Sí** | Saldo deudor en dólares (compras - pagos). |
| `totalCompras` | `Double` | No | Monto acumulado histórico comprado. |
| `totalPagado` | `Double` | No | Monto acumulado histórico abonado. |
| `creadoEn` | `Timestamp` | **Sí** | Fecha de vinculación o alta. |

---

### 3.5. `prendas` (Inventario / Catálogo de Productos)
Catálogo de ropa y accesorios perteneciente a cada emprendedor.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `doc.id` | `String` | **Sí** | Identificador de la prenda. |
| `adminId` | `String` | **Sí** | Dueño de la prenda (`Administradores`). |
| `nombre` | `String` | **Sí** | Título o descripción (ej. *"Vestido floral vintage"*). |
| `tipo` | `String` | No | Categoría (`Vestido`, `Falda`, `Pantalón`, etc.). |
| `color` | `String` | No | Color de la prenda. |
| `talla` | `String` | No | Talla física (`S`, `M`, `L`, etc.). |
| `codigoPrenda` | `String` | No | Código visible en etiqueta o perchero. |
| `precio` | `Double` | **Sí** | Valor unitario en dólares. |
| `stock` | `Integer`| **Sí** | Cantidad disponible en percha/bodega. |
| `imagenUrl` | `String` | No | Enlace a la fotografía subida a Cloudinary. |
| `disponible` | `Boolean`| **Sí** | `true` si se puede ofertar en el Live. |
| `fecha_creacion`| `Timestamp` | **Sí** | Fecha de ingreso al inventario. |

---

### 3.6. `compras` (Ventas y Pedidos en Tiempo Real)
Cada pedido realizado por un cliente en un Live o en el local físico.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `doc.id` | `String` | **Sí** | Identificador de la orden. |
| `adminId` | `String` | **Sí** | Negocio donde se efectúa la venta. |
| `clienteId` | `String` | **Sí** | ID del cliente comprador. |
| `prendaId` | `String` | No | ID de la prenda vendida en `prendas`. |
| `secretarioId` | `String` | No | Operador que anotó el pedido en vivo. |
| `nombreCliente` | `String` | **Sí** | Nombre del cliente (desnormalizado). |
| `nombrePrenda` | `String` | **Sí** | Nombre del producto. |
| `precio` | `Double` | **Sí** | Precio unitario aplicado. |
| `cantidad` | `Integer`| **Sí** | Número de prendas (por defecto 1). |
| `subtotal` | `Double` | **Sí** | `precio * cantidad`. |
| `estado` | `String` | **Sí** | `'pendiente'`, `'entregado'`, `'cancelado'`. |
| `tipoEnvio` | `String` | No | `'retiro_local'` o `'delivery'`. |
| `fecha` | `Timestamp` | **Sí** | Momento de la compra en vivo. |

---

### 3.7. `pagos` (Abonos y Cobranzas)
Transacciones financieras que liquidan o amortizan el saldo deudor de los clientes.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `doc.id` | `String` | **Sí** | Identificador del abono. |
| `adminId` | `String` | **Sí** | Negocio que recibe el dinero. |
| `clienteId` | `String` | **Sí** | Cliente que amortiza su deuda. |
| `compraId` | `String` | No | Vinculación a una compra específica si aplica. |
| `secretarioId` | `String` | No | Secretario que recibió el pago. |
| `clienteNombre` | `String` | No | Nombre del cliente. |
| `monto` | `Double` | **Sí** | Valor abonado en dólares USD. |
| `metodoPago` | `String` | **Sí** | `'Efectivo'`, `'Transferencia'`, `'DeUna'`, etc. |
| `comprobanteUrl`| `String` | No | Foto del recibo o voucher subido a Cloudinary. |
| `notas` | `String` | No | Referencia bancaria o detalle de pago. |
| `fecha` | `Timestamp` | **Sí** | Fecha y hora de recepción del dinero. |

---

### 3.8. `fotos_perfil` (Control de Media en Nube)
Colección auxiliar para indexar imágenes subidas a **Cloudinary CDN** y liberar a Firestore del almacenamiento binario.

| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `doc.id` / `uid` | `String` | **Sí** | Coincide con el `uid` del usuario. |
| `url` | `String` | **Sí** | URL segura HTTPS en Cloudinary. |
| `publicId` | `String` | No | ID interno de Cloudinary para reemplazos/borrado. |
| `actualizadoEn`| `Timestamp` | **Sí** | Fecha de subida o reemplazo de foto. |

---

## 4. Flujo de Negocio y Relaciones Clave

1. **Ciclo de Vinculación y Código de Live:**
   * El emprendedor aprueba a un secretario en `secretarios`.
   * El secretario genera o recibe un `codigoLive` (ej. `HCC-929`).
   * Cuando un cliente ingresa a la app, digita el código en `EnterCodeScreen`, lo cual actualiza automáticamente su documento en `usuarios` y `clientes` con el `adminId` y `secretarioId` correspondientes.
2. **Ciclo de Compras y Deuda en Vivo:**
   * Durante una transmisión, el secretario ingresa pedidos en `compras`.
   * El cliente visualiza en tiempo real en `ClientHomeScreen` y `ClientBalanceScreen` su saldo pendiente recalculado:
     $$\text{Saldo Pendiente} = \sum \text{compras.subtotal} - \sum \text{pagos.monto}$$
3. **Ciclo de Gestión Multi-empleo (Secretarios):**
   * Un usuario cliente puede postularse a varias tiendas en `SolicitudEmpleoScreen`.
   * Cada postulación genera un registro en `secretarios` (`${clienteId}_${adminId}`).
   * Cuando un emprendedor aprueba la solicitud (`aprobado: true`), en el perfil del cliente se desbloquea el botón **"Cambiar a modo Secretario"**, permitiéndole alternar entre ser cliente o trabajar para esa tienda.
