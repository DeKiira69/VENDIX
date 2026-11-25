# VENDIX — ESPECIFICACIÓN TÉCNICA DE DISEÑO PARA PLANTILLAS XLSX

**Documento:** Guía Maestra de Especificación y Mapeo de Plantillas Excel  
**Archivos Objetivo:** `assets/templates/VendiX_Admin.xlsx` y `assets/templates/VendiX_Secretario.xlsx`  
**Destino de Conversión:** Google Sheets API vía Google Drive API v3  
**Moneda Oficial:** Dólar Estadounidense (USD - `$`)  
**Zona Horaria de Referencia:** `America/Guayaquil` (UTC-5)  

---

## 1. Introducción y Propósito

El presente documento define la especificación técnica, dimensional y estructural requerida para diseñar externamente las dos plantillas maestras en formato Microsoft Excel OpenXML (`.xlsx`) que utiliza VendiX para la exportación de reportes comerciales:

1. **`VendiX_Admin.xlsx`**: Plantilla para el Emprendedor / Administrador de la tienda. Contiene la visión integral de ventas, cobros, cartera de clientes, catálogo, jornadas y ranking de rendimiento de vendedores.
2. **`VendiX_Secretario.xlsx`**: Plantilla para el Operador de Ventas / Secretario. Contiene únicamente información operativa autorizada (ventas del negocio, catálogo, clientes y los cobros registrados por él mismo). **Excluye deliberadamente el ranking de vendedores, comparativas de desempeño y cobros de terceros**.

Ambas plantillas funcionan como modelos en blanco (*templates*) pre-formateados con tablas estructuradas, estilos institucionales de VendiX (tonos violetas `#6C4AB6`, verdes esmeralda `#2E7D32` y grises neutros), encabezados fijos y filtros automáticos. La aplicación móvil Flutter copia la plantilla en memoria y rellena las filas con datos reales autorizados de Cloud Firestore antes de entregar el archivo al usuario o subirlo a Google Drive.

---

## 2. Requisitos Generales de Diseño y Compatibilidad

Para asegurar que los archivos mantengan su integridad visual tanto al abrirse en Microsoft Excel móvil/escritorio como al ser convertidos automáticamente a hojas de cálculo nativas en **Google Drive / Google Sheets**, las plantillas deben cumplir estrictamente con:

1. **Formato de Archivo:** Formato estándar `.xlsx` (OpenXML Spreadsheet). No utilizar formatos heredados `.xls` ni macros `.xlsm`.
2. **Tablas Estructuradas con Encabezados Claros:** Cada conjunto de datos debe comenzar en una fila predeterminada con una fila de encabezados formateada con fondo de color sólido institucional y texto en negrita.
3. **Filtros Automáticos:** Activar el filtro por columnas (`Data AutoFilter`) en la fila de encabezados de cada tabla de datos.
4. **Formatos Numéricos y Monetarios:**
   - Valores monetarios: Formato de moneda con dos decimales y símbolo de dólar: `$#,##0.00`.
   - Cantidades y stock: Formato entero sin decimales: `#,##0`.
   - Porcentajes: Formato porcentual con un decimal: `0.0%`.
5. **Formatos de Fecha y Hora:**
   - Fechas con hora: Formato estandarizado `yyyy-mm-dd hh:mm` (ejemplo: `2026-11-25 14:30`).
   - Fechas simples: `yyyy-mm-dd`.
6. **Sin Dashboards ni Gráficos Embebidos:** La exportación debe enfocarse exclusivamente en datos tabulares limpios, auditables y estructurados. No incorporar gráficos de barras, circulares ni formas decorativas flotantes que puedan corromperse durante la conversión en Google Drive API.
7. **Nombres de Hojas Estandarizados:** Los nombres de las hojas no deben contener caracteres especiales, barras ni superar los 30 caracteres.

---

## 3. Especificación Detallada: Plantilla del Administrador (`VendiX_Admin.xlsx`)

La plantilla del administrador consta de **7 hojas de cálculo independientes**:

```text
VendiX_Admin.xlsx
 ├── 1. Resumen General
 ├── 2. Historial Ventas
 ├── 3. Historial Cobros
 ├── 4. Cartera Clientes
 ├── 5. Inventario Prendas
 ├── 6. Jornadas Live
 └── 7. Ranking Vendedores
```

---

### Hoja 1: `Resumen General`

* **Finalidad:** Tarjeta ejecutiva con los totales comerciales y métricas consolidadas del negocio.
* **Estructura de Filas:**
  - `A1:B1` (Combinado): Título institucional `VENDIX — REPORTE COMERCIAL CONSOLIDADO` (Fondo Violeta `#6C4AB6`, Texto Blanco Negrita, 14pt).
  - `A2:B2`: Metadatos generales:
    - `A2`: `Emprendimiento:`, `B2`: `[Nombre de la Tienda]`
    - `A3`: `Generado por:`, `B3`: `[Nombre del Administrador]`
    - `A4`: `Fecha de Generación:`, `B4`: `[Fecha y Hora]`
  - `A6:B6`: Encabezados `MÉTRICA COMERCIAL` | `VALOR CONSOLIDADO`
* **Mapeo de Campos:**

| Fila | Métrica Comercial (Columna A) | Valor / Fórmula (Columna B) | Tipo de Dato | Origen en Firestore |
|---|---|---|---|---|
| 7 | Total Facturado / Vendido | `=SUM('Historial Ventas'!I2:I1000)` | Moneda (`$#,##0.00`) | Suma de `subtotal` en `/compras` |
| 8 | Total Recaudado / Cobrado | `=SUM('Historial Cobros'!E2:E1000)` | Moneda (`$#,##0.00`) | Suma de `monto` en `/pagos` |
| 9 | Saldo Pendiente en Cartera | `=SUM('Cartera Clientes'!H2:H1000)` | Moneda (`$#,##0.00`) | Suma de `saldoPendiente` en `/clientes` |
| 10 | Prendas Totales Vendidas | `=SUM('Historial Ventas'!H2:H1000)` | Entero (`#,##0`) | Suma de `cantidad` en `/compras` |
| 11 | Número de Ventas Realizadas | `=COUNTA('Historial Ventas'!A2:A1000)` | Entero (`#,##0`) | Conteo de transacciones |
| 12 | Ticket Promedio por Venta | `=IFERROR(B7/B11, 0)` | Moneda (`$#,##0.00`) | Cálculo derivado |
| 13 | Total de Clientes Registrados | `=COUNTA('Cartera Clientes'!A2:A1000)` | Entero (`#,##0`) | Conteo en `/clientes` |
| 14 | Total de Artículos en Catálogo | `=COUNTA('Inventario Prendas'!A2:A1000)` | Entero (`#,##0`) | Conteo en `/prendas` |
| 15 | Total de Jornadas Live Realizadas | `=COUNTA('Jornadas Live'!A2:A1000)` | Entero (`#,##0`) | Conteo en `/jornadas` |

---

### Hoja 2: `Historial Ventas`

* **Finalidad:** Auditoría de cada transacción comercial adjudicada a clientes durante transmisiones en vivo o ventas directas.
* **Encabezados (Fila 1):**

| Col | Nombre Encabezado | Tipo de Dato | Formato | Campo en Firestore | Descripción |
|---|---|---|---|---|---|
| **A** | Código Venta | Texto | General | `codigo` / `id` | Identificador único (`Vent001`) |
| **B** | Fecha y Hora | FechaHora | `yyyy-mm-dd hh:mm` | `fecha` | Marca de tiempo UTC-5 |
| **C** | Nombre Cliente | Texto | General | `clienteNombre` | Nombre del comprador |
| **D** | Código Cliente | Texto | General | `clienteId` | Identificador (`cli001_Nombre`) |
| **E** | Prenda Adjudicada | Texto | General | `prendaNombre` | Nombre de la prenda |
| **F** | Código Prenda | Texto | General | `prendaId` | Identificador (`Prend001_...`) |
| **G** | Precio Unitario | Decimal | `$#,##0.00` | `precioUnitario` | Precio fijado por unidad |
| **H** | Cantidad | Entero | `#,##0` | `cantidad` | Unidades vendidas |
| **I** | Subtotal | Decimal | `$#,##0.00` | `subtotal` / `=G2*H2` | Importe total de la línea |
| **J** | Estado | Texto | General | `estado` | `confirmada`, `entregada`, `anulada` |
| **K** | Jornada Live | Texto | General | `jornadaId` | Transmisión en vivo asociada |
| **L** | Registrado Por | Texto | General | `registradoPorNombre` | Operador físico que registró la venta |
| **M** | Rol Responsable | Texto | General | `rolResponsable` | `administrador` o `secretario` |

* **Ejemplo de Fila de Datos:**
  `Vent001 | 2026-11-25 20:15 | Diana Paredes | cli001_DianaParedes | Chaqueta Cuero | Prend001_ChaquetaCuero | $45.00 | 1 | $45.00 | confirmada | Jorn001_LiveNavidad | Carla Gomez | secretario`

---

### Hoja 3: `Historial Cobros`

* **Finalidad:** Registro financiero de abonos, transferencias y pagos en efectivo recaudados.
* **Encabezados (Fila 1):**

| Col | Nombre Encabezado | Tipo de Dato | Formato | Campo en Firestore | Descripción |
|---|---|---|---|---|---|
| **A** | Código Pago | Texto | General | `codigo` / `id` | Identificador único (`Pago001`) |
| **B** | Fecha y Hora | FechaHora | `yyyy-mm-dd hh:mm` | `fecha` | Marca de tiempo UTC-5 |
| **C** | Nombre Cliente | Texto | General | `clienteNombre` | Nombre del cliente que abona |
| **D** | Código Cliente | Texto | General | `clienteId` | Identificador (`cli001_Nombre`) |
| **E** | Monto Cobrado | Decimal | `$#,##0.00` | `monto` | Valor abonado |
| **F** | Forma de Pago | Texto | General | `formaPago` / `metodoPago` | Efectivo, Transferencia, Depósito |
| **G** | Observación / Comprobante | Texto | General | `observacion` | Detalle o número de referencia |
| **H** | Jornada Live | Texto | General | `jornadaId` | Evento Live donde se recibió |
| **I** | Recibido Por | Texto | General | `recibidoPorNombre` | Operador que cobró el dinero |
| **J** | Rol Responsable | Texto | General | `rolResponsable` | `administrador` o `secretario` |

* **Ejemplo de Fila de Datos:**
  `Pago001 | 2026-11-25 20:30 | Diana Paredes | cli001_DianaParedes | $25.00 | Transferencia Pichincha | Ref #44912 | Jorn001_LiveNavidad | Carla Gomez | secretario`

---

### Hoja 4: `Cartera Clientes`

* **Finalidad:** Estado de cuenta consolidado y saldos deudores de clientes.
* **Encabezados (Fila 1):**

| Col | Nombre Encabezado | Tipo de Dato | Formato | Campo en Firestore | Descripción |
|---|---|---|---|---|---|
| **A** | Código Cliente | Texto | General | `codigo` / `id` | `cli001_DianaParedes` |
| **B** | Nombre Completo | Texto | General | `nombre` | Nombre y apellido |
| **C** | Teléfono | Texto | General | `telefono` | Contacto telefónico |
| **D** | Correo Electrónico | Texto | General | `correo` | Email del cliente |
| **E** | Dirección Domiciliaria | Texto | General | `direccion` | Dirección de envío |
| **F** | Total Compras | Decimal | `$#,##0.00` | `totalCompras` | Facturación acumulada |
| **G** | Total Pagado | Decimal | `$#,##0.00` | `totalPagado` | Amortización acumulada |
| **H** | Saldo Pendiente | Decimal | `$#,##0.00` | `saldoPendiente` / `=F2-G2` | Cartera por cobrar |

---

### Hoja 5: `Inventario Prendas`

* **Finalidad:** Catálogo de productos, existencias disponibles y precios unitarios.
* **Encabezados (Fila 1):**

| Col | Nombre Encabezado | Tipo de Dato | Formato | Campo en Firestore | Descripción |
|---|---|---|---|---|---|
| **A** | Código Prenda | Texto | General | `codigo` / `id` | `Prend001_ChaquetaCuero` |
| **B** | Nombre de la Prenda | Texto | General | `nombre` | Denominación del artículo |
| **C** | Precio Oficial | Decimal | `$#,##0.00` | `precio` | Precio unitario de catálogo |
| **D** | Stock Disponible | Entero | `#,##0` | `stock` | Unidades físicas en bodega |
| **E** | Estado Catálogo | Texto | General | `activa` | `Activa` o `Inactiva` |

---

### Hoja 6: `Jornadas Live`

* **Finalidad:** Resumen por cada transmisión en vivo realizada.
* **Encabezados (Fila 1):**

| Col | Nombre Encabezado | Tipo de Dato | Formato | Campo en Firestore | Descripción |
|---|---|---|---|---|---|
| **A** | Código Jornada | Texto | General | `codigo` / `id` | `Jorn001_LiveNavidad` |
| **B** | Nombre Transmisión | Texto | General | `nombre` | Título del evento en vivo |
| **C** | Fecha de Inicio | FechaHora | `yyyy-mm-dd hh:mm` | `fechaInicio` | Momento de apertura del live |
| **D** | Estado | Texto | General | `activa` | `En Vivo (Activa)` o `Finalizada` |
| **E** | Total Vendido | Decimal | `$#,##0.00` | `totalVendido` | Facturación durante el live |
| **F** | Total Cobrado | Decimal | `$#,##0.00` | `totalCobrado` | Recaudación durante el live |

---

### Hoja 7: `Ranking Vendedores` (Exclusiva del Administrador)

* **Finalidad:** Evaluación de desempeño comercial de secretarios y administrador.
* **Encabezados (Fila 1):**

| Col | Nombre Encabezado | Tipo de Dato | Formato | Origen del Dato |
|---|---|---|---|---|
| **A** | Posición | Entero | `0` | Índice correlativo (1, 2, 3...) |
| **B** | Responsable | Texto | General | Nombre del vendedor |
| **C** | Rol Comercial | Texto | General | `ADMINISTRADOR` o `SECRETARIO` |
| **D** | N° de Ventas | Entero | `#,##0` | Total de compras registradas |
| **E** | Prendas Vendidas | Entero | `#,##0` | Total de unidades adjudicadas |
| **F** | Total Vendido | Decimal | `$#,##0.00` | Importe acumulado en ventas |
| **G** | Ticket Promedio | Decimal | `$#,##0.00` | Total Vendido / N° de Ventas |
| **H** | % Participación | Porcentaje | `0.0%` | (Total Vendido / Total General) * 100 |
| **I** | Total Cobrado | Decimal | `$#,##0.00` | Recaudación de pagos recibidos |

---

## 4. Especificación Detallada: Plantilla del Secretario (`VendiX_Secretario.xlsx`)

La plantilla del secretario cuenta con **6 hojas de cálculo**. Está diseñada con el principio de **privilegio mínimo y restricción estricta de datos sensibles**:

```text
VendiX_Secretario.xlsx
 ├── 1. Resumen Operativo
 ├── 2. Historial Ventas
 ├── 3. Mis Cobros Registrados
 ├── 4. Cartera Clientes
 ├── 5. Inventario Prendas
 └── 6. Jornadas Live
```

### Reglas de Exclusión Obligatorias para la Plantilla del Secretario:
1. **Sin Hoja de Ranking:** No incluye la hoja `Ranking Vendedores`.
2. **Aislamiento en Cobros:** La hoja `Mis Cobros Registrados` contiene **exclusivamente** los abonos recaudados por el secretario autenticado (`recibidoPorId == currentSecretaryUid`). No se muestran los cobros del administrador ni de otros secretarios.
3. **Resumen Operativo Limitado:** En `Resumen Operativo` únicamente se totalizan las ventas generales del negocio y los cobros individuales del secretario. No se muestran utilidades, cartera global de cobro ni comparativas.

---

## 5. Mapeo de Diccionario de Datos Cloud Firestore

La siguiente tabla detalla la correspondencia entre los tipos de datos de Firestore y los tipos de celdas en el motor XLSX:

| Colección Firestore | Campo Firestore | Tipo de Dato Firestore | Tipo en XLSX | Celda Excel (`excel: ^4.0.6`) |
|---|---|---|---|---|
| `compras` | `id`, `codigo` | `String` | Texto | `TextCellValue(val)` |
| `compras` | `fecha` | `Timestamp` / `DateTime` | Fecha y Hora | `TextCellValue('yyyy-mm-dd hh:mm')` |
| `compras` | `precioUnitario` | `num` / `double` | Decimal Moneda | `DoubleCellValue(val)` |
| `compras` | `cantidad` | `num` / `int` | Entero | `IntCellValue(val)` |
| `compras` | `subtotal` | `num` / `double` | Decimal Moneda | `DoubleCellValue(val)` |
| `pagos` | `monto` | `num` / `double` | Decimal Moneda | `DoubleCellValue(val)` |
| `clientes` | `saldoPendiente` | `num` / `double` | Decimal Moneda | `DoubleCellValue(val)` |
| `prendas` | `stock` | `num` / `int` | Entero | `IntCellValue(val)` |
| `jornadas` | `activa` | `bool` | Texto | `TextCellValue('En Vivo' / 'Finalizada')` |

---

## 6. Recomendaciones para el Diseñador Externo de Plantillas

Al diseñar los dos archivos `.xlsx` en Microsoft Excel o LibreOffice Calc:

1. **Estilo de Encabezados:**
   - Color de relleno de encabezados: Violeta oscuro `#4D2C91` o Verde VendiX `#2E7D32`.
   - Color de fuente: Blanco (`#FFFFFF`), tipografía `Segoe UI` o `Arial`, tamaño `10pt` o `11pt`, Negrita (`Bold`).
   - Alineación: Centrada vertical y horizontalmente.
2. **Bordes:** Bordes sutiles en gris claro (`#D1C4E9` o `#E0E0E0`) en todas las celdas de datos.
3. **Ancho de Columnas:** Establecer un ancho predeterminado holgado (mínimo 15 a 25 caracteres) para evitar que los valores numéricos aparezcan truncados como `###` al abrir el documento en dispositivos móviles.
4. **Almacenamiento en el Proyecto:**
   Una vez terminados los diseños, colocar ambos archivos exactamente en:
   ```text
   assets/templates/VendiX_Admin.xlsx
   assets/templates/VendiX_Secretario.xlsx
   ```
   El motor implementado en `lib/services/reports/excel_report_service.dart` los detectará, cargará en memoria y completará sus filas automáticamente.
