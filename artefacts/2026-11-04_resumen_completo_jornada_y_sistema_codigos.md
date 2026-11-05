# Bitácora Completa de Trabajo y Arquitectura - 04 de Noviembre de 2026

## Proyecto: VENDIX - Plataforma de Comercio y Ventas en Vivo
**Fecha:** 4 de noviembre de 2026  
**Autor:** Antigravity AI (Pair Programming)  
**Estado del Repositorio:** Sincronizado en rama `main` (`https://github.com/DeKiira69/VENDIX.git`)  
**Estado de Análisis:** 0 errores, 0 advertencias (`dart analyze lib/` -> No issues found!)

---

## 1. Resumen Ejecutivo de lo Realizado Hoy

Durante la jornada se abordaron y completaron los siguientes hitos estructurales críticos:

1. **Eliminación Total y Definitiva de Datos de Prueba (Mock Data):**
   * Se erradicó por completo el archivo `lib/data/datos_prueba.dart`.
   * Se eliminaron todas las clases demo: `ClienteDemo`, `PrendaDemo`, `CompraDemo`, `PagoDemo`, `JornadaDemo` y listas estáticas `clientesDemo`, `prendasDemo`, `jornadasDemo`.
   * Todas las pantallas del módulo de Secretaría ahora leen y escriben 100% en vivo sobre las colecciones de Firebase Firestore.

2. **Migración Completa de Pantallas a Firebase Firestore:**
   * **`lib/screens/secretary/clients_screen.dart`**:
     * Lectura reactiva de `clientes`, `compras` y `pagos` mediante `StreamBuilder`.
     * Cálculo dinámico de saldo pendiente (`deuda = totalComprado - totalPagado`), prendas adquiridas y estado de cuenta ('Todas', 'Con saldo', 'Al día').
     * Registro de nuevas clientas directamente en la colección `clientes`.
     * Registro de compras directas (`compras`) seleccionando prendas reales del catálogo activo (`prendas`).
     * Registro de pagos y abonos en tiempo real (`pagos`) con validación de montos.
     * Modal de historial con desglose detallado de compras y pagos.
   * **`lib/screens/secretary/quick_sales_screen.dart`**:
     * Pantalla de ventas rápidas durante el Live.
     * Lectura de clientas reales desde Firestore con buscador en vivo.
     * Lectura de prendas activas desde `prendas` vía `PrendaModel`.
     * Carrito reactivo en memoria por clienta durante la transmisión.
     * Registro transaccional por lotes (`WriteBatch`) en la colección `compras` al confirmar la venta.
   * **`lib/screens/secretary/home_screen.dart`**:
     * Resumen en vivo de ingresos de hoy, ventas totales, clientas registradas y prendas vendidas.
   * **`lib/screens/secretary/statistics_screen.dart`**:
     * Gráficas y balances financieros consolidados en tiempo real desde Firestore.
   * **`lib/screens/secretary/jornadas_screen.dart`**:
     * Apertura, cronómetro y cierre de jornadas de live persistidas en la colección `jornadas`.
   * **`lib/screens/secretary/payments_screen.dart`**:
     * Registro formal de abonos con observación, control de saldos y selección de clientas reales.

3. **Vinculación de Secretarios al Administrador / Emprendedor (`adminId`):**
   * En `lib/screens/admin/admin_more_screen.dart`, al momento de registrar directamente o aprobar una solicitud de secretario, se graba obligatoriamente el `adminId` del administrador que lo admitió.
   * Las listas de secretarios activos ahora se filtran por dicho `adminId`, garantizando que cada administrador únicamente visualice y administre a sus propios operadores.
   * Las solicitudes pendientes siguen visibles para que cualquier administrador con credenciales pueda evaluarlas.

4. **Autenticación Git y Despliegue Remoto a GitHub:**
   * Se resolvieron los bloqueos de red y protocolo HTTP de Git.
   * Se configuró el buffer y compresión adecuada para repositorios con assets.
   * Tras la autorización del usuario mediante el *Git Credential Manager*, se realizó con éxito el comando `git push origin main` hacia el repositorio público/privado `https://github.com/DeKiira69/VENDIX.git`.

---

## 2. Mapa de Colecciones Firestore Activas

| Colección | Propósito | Campos Clave |
|---|---|---|
| `Administradores/{uid}` | Cuentas de emprendedores/dueños | `id`, `nombre`, `correo`, `telefono`, `fotoPerfil`, `rol` |
| `secretarios/{uid}` | Cuentas de secretarios/operadores | `uid`, `nombre`, `correo`, `adminId`, `estado`, `aprobado`, `codigoLive` |
| `usuarios/{uid}` | Directorio general de accesos | `uid`, `correo`, `rol`, `adminId`, `creadoEn` |
| `clientes/{uid}` | Perfiles de clientas registradas | `uid`, `nombre`, `telefono`, `direccion`, `adminId`, `secretarioId`, `codigoIngreso` |
| `prendas/{id}` | Catálogo de ropa del emprendedor | `nombre`, `precio`, `activa`, `stock`, `fecha_creacion` |
| `compras/{id}` | Registro de cada venta | `clienteId`, `clienteNombre`, `prenda`, `precio`, `cantidad`, `total`, `fecha` |
| `pagos/{id}` | Registro de abonos y cancelaciones | `clienteId`, `clienteNombre`, `monto`, `observacion`, `fecha` |
| `jornadas/{id}` | Sesiones de transmisiones en vivo | `nombre`, `fecha`, `estado`, `horaInicio`, `horaFin` |

---

## 3. Planificación Arquitectónica: Código de Live Obligatorio para Clientes

### 3.1. Objetivo del Requerimiento
Establecer un flujo obligatorio donde un cliente no puede registrarse en la plataforma sin ingresar un código emitido por un secretario durante un Live. A través de este código, el cliente queda automáticamente enlazado al Emprendedor (Administrador) para el cual trabaja dicho secretario, visualizando los datos y catálogo de ese Emprendedor.

### 3.2. Dinámica del Flujo
```
[Emprendedor (Admin)]
         │
         ▼ (aprueba y vincula con adminId)
[Secretario / Operador en Live]
         │
         ▼ (Genera código en su pantalla de perfil: ej. "VENDIX-7821")
[Código del Live emitido]
         │
         ▼ (El cliente ve el Live y copia el código)
[Registro del Cliente (App)]
         │──> Campo obligatorio: CÓDIGO DE INGRESO
         │──> Validación en Firestore (busca el secretario dueño del código)
         │──> Extrae el adminId del Emprendedor correspondiente
         ▼
[Cliente Creado y Vinculado]
         │──> Guarda: { adminId: adminId, secretarioId: secretarioUid, codigoLive: "..." }
         ▼
[Home del Cliente]
         │──> Muestra los datos del Emprendedor (Marca / Negocio del Admin)
```

### 3.3. Componentes a Modificar / Crear
1. **Perfil del Secretario (`lib/screens/secretary/more_screen.dart`):**
   * Sección destacada para **"Código de Live"**.
   * Botón para generar un código único automáticamente (ej. 6 caracteres alfanuméricos como `VX-9428` o código aleatorio legible).
   * Almacenamiento en Firestore en el documento de `secretarios/{uid}` (`codigoLive`, `fechaCodigoLive`).
   * Visualización grande del código con botón rápido de "Copiar al portapapeles" y "Compartir".

2. **Registro de Cliente (`lib/screens/auth/register_client_screen.dart`):**
   * Agregar campo de texto obligatorio **"Código del Live"** con validación estricta (no permite avanzar si está vacío).
   * Verificación asíncrona contra Firestore: buscar en la colección `secretarios` el documento donde `codigoLive == codigoIngresado`.
   * Si no existe o está inactivo: alerta roja *"El código ingresado no es válido o ha expirado"*.
   * Si es válido: obtiene el `adminId` y nombre del emprendedor.
   * Vincula al cliente con `adminId: secretarioDoc['adminId']` y `secretarioId: secretarioDoc.id`.
   * Lo mismo aplicará si se registra mediante Google Sign-In (el modal de datos pedirá el código obligatorio).

3. **Pantalla Principal del Cliente (`lib/screens/client/client_home_screen.dart` y `client_profile_screen.dart`):**
   * Mostrar el encabezado con la información del Emprendedor vinculado (Nombre del negocio / Administrador, contacto o soporte).

---

## 4. Estado de Verificación
* **Archivos modificados y confirmados:**
  * `lib/screens/secretary/clients_screen.dart` (rehecho a Firestore)
  * `lib/screens/secretary/quick_sales_screen.dart` (rehecho a Firestore)
  * `lib/screens/secretary/home_screen.dart` (rehecho a Firestore)
  * `lib/screens/secretary/statistics_screen.dart` (rehecho a Firestore)
  * `lib/screens/secretary/jornadas_screen.dart` (rehecho a Firestore)
  * `lib/screens/secretary/payments_screen.dart` (rehecho a Firestore)
  * `lib/screens/admin/admin_more_screen.dart` (vinculación `adminId`)
* **Archivo eliminado:** `lib/data/datos_prueba.dart`
* **Compilación y análisis:** 0 errores, 0 warnings.
