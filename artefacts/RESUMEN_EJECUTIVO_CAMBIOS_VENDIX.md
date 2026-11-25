# VendiX — Resumen Ejecutivo de Cambios y Mejoras Recientes

Este documento resume de manera sencilla, clara y comprensible los cambios arquitectónicos y funcionales realizados recientemente en la aplicación móvil **VendiX**.

---

## 1. Corrección en el Registro e Inicio de Sesión con Google

### ¿Qué problema había antes?
Al autenticarse con una cuenta de Google, el sistema obligaba al usuario a elegir únicamente entre dos opciones:
1. **Entrar como cliente** (comprador).
2. **Buscar empleo** para trabajar como secretario.

**No existía la opción de entrar como Emprendedor (Administrador)** mediante Google. Si alguien quería registrar su propia tienda, el flujo de Google no se lo permitía. Además, el formulario inicial exigía el número de teléfono como obligatorio y pedía configurar la dirección de la tienda mediante mapas de forma prematura.

### ¿Cómo quedó solucionado ahora?
1. **Opción "Trabajar como emprendedor":**
   - Ahora, en el panel principal de bienvenida tras ingresar con Google, aparece claramente la opción de **"Trabajar como emprendedor"**.
   - Al pulsarla, la aplicación **únicamente solicita el nombre del emprendimiento**, nada más. De forma automática se crea la tienda y se le asigna el rol de Administrador.
2. **Teléfono 100% opcional:**
   - El número de teléfono ya no es obligatorio para ningún usuario ni rol al registrarse.
3. **Dirección física removida de los registros:**
   - Ya no se pide dirección física ni ubicación GPS en ningún formulario de registro inicial.
   - La dirección ahora se configura tranquilamente después, directamente desde el **Panel del Administrador** en la sección de *Editar Emprendimiento*.

---

## 2. Nuevo Sistema de Identificadores (IDs Amigables y Consecutivos)

### ¿Qué problema había antes?
Anteriormente, Firebase creaba códigos aleatorios y confusos de letras y números desordenados (por ejemplo: `7fA9kLmQz18vPxR3tWb0`). 
- En una transmisión en vivo, era imposible que un cliente o secretario pudiera dictar o memorizar esos códigos.
- Al revisar la base de datos o listas, no se sabía a simple vista si un código pertenecía a un cliente, a una prenda o a un pago.

### ¿Cómo funciona ahora?
Se creó un sistema automático e inteligente que genera identificadores **consecutivos, ordenados y fáciles de leer**:

| Tipo de Registro | Formato Anterior (Aleatorio) | Formato Actual (Amigable y Consecutivo) | Ejemplo Real |
|---|---|---|---|
| **Clientes** | `xK81jQm9La2...` | `cli` + Número + Nombre | `cli001_DianaParedes` |
| **Administradores** | `9pZ34vBx11...` | `Admin` + Número + Nombre | `Admin001_AlexisMora` |
| **Secretarios** | `Qw56Rty78...` | `Secre` + Número + Nombre | `Secre001_CarlaGomez` |
| **Prendas (Ropa)** | `12Az90Xcv...` | `Prend` + Número + Prenda | `Prend001_ChaquetaCuero` |
| **Ventas (Compras)** | `pQ71Nm45...` | `Vent` + Número consecutivo | `Vent001`, `Vent002`, `Vent003` |
| **Pagos (Abonos)** | `mM8901Kl...` | `Pago` + Número consecutivo | `Pago001`, `Pago002`, `Pago003` |
| **Jornadas Live** | `Lp0012Ab...` | `Jorn` + Número + Nombre | `Jorn001_LiveNavidad` |

> [!TIP]
> **Sin duplicados ni bloqueos:** El sistema utiliza un contador automático en la base de datos. Si dos personas venden al mismo tiempo, el sistema les asigna automáticamente números distintos sin colisiones ni errores.

---

## 3. Trazabilidad Comercial (Saber quién hizo qué)

Durante una transmisión en vivo, varias personas pueden estar colaborando al mismo tiempo. Para que no existan confusiones sobre el dinero ni los pedidos:

- Ahora, cada vez que se anota una **venta** o se recibe un **pago**, VendiX guarda en segundo plano:
  - **Quién lo registró:** El nombre exacto de la persona (dueño o secretario).
  - **Su rol:** Si actuó como administrador o como secretario.
  - **El evento en vivo:** En qué transmisión Live se realizó (`jornadaId`).
  - **El negocio:** A qué emprendimiento pertenece la venta.
- **Beneficio:** Esto permitirá en el futuro saber con exactitud cuánto vendió cada secretario, calcular comisiones y tener un ranking de ventas sin errores humanos.

---

## 4. Estado de los Reportes: Situación con Google Sheets y Alternativa Futura

### ¿Por qué no pudimos implementar Google Sheets directamente?
La idea inicial consistía en que la aplicación creara automáticamente una hoja de cálculo en **Google Sheets** mediante su API oficial. 

Sin embargo, al probarlo en teléfonos reales surgieron problemas insalvables con la arquitectura anterior:
1. **Errores de permisos de acceso:** Los documentos dependían de una cuenta central de Google Drive. Cuando un compañero de pruebas intentaba abrir la hoja con su propio correo, Google bloqueaba la pantalla mostrando: *"¿Solicitar acceso al propietario del archivo?"* y *"No se puede acceder al documento"*.
2. **Exclusión de otros correos:** Quienes no utilizaban cuenta de Google (correos Hotmail, Outlook o institucionales) no podían descargar reportes.
3. **Complejidad de permisos OAuth:** Google exigía permisos invasivos sobre los archivos personales del usuario.

Por estos motivos, **se retiró por completo la integración defectuosa de Google Sheets** de la aplicación para que la versión actual sea 100% estable, no arroje errores en pantalla y pueda ser probada sin inconvenientes por el equipo.

### ¿Cuál es la alternativa que utilizaremos en el futuro?
En lugar de depender directamente de la creación online en Google Sheets, utilizaremos una solución mucho más práctica, independiente y profesional:

```text
[ Base de Datos VendiX ] 
          ↓
[ Plantilla local pre-diseñada (.XLSX) dentro de la App ] 
          ↓
[ El usuario descarga directamente su archivo Excel ]
          ↓ (Opcional)
[ Subir a su propia cuenta de Google Drive mediante Google Drive API ]
```

1. **Plantillas Excel Locales:** Ya contamos con dos plantillas diseñadas profesionalmente (`VendiX_Admin.xlsx` y `VendiX_Secretario.xlsx`).
2. **Generación directa en el celular:** La aplicación rellenará los datos de las ventas en el archivo Excel directamente dentro del teléfono.
3. **Descarga universal:** Cualquier usuario podrá abrir o compartir su reporte Excel por WhatsApp, correo o descargarlo a su teléfono sin importar si tiene cuenta de Google o no.
4. **Integración con Google Drive API:** Quien lo desee, podrá pulsar un botón para subir una copia de respaldo a su propia cuenta de Google Drive, cumpliendo de manera limpia y sin fallos con el requisito de integración de APIs.

---

## Resumen del Estado Actual de la App

- ✅ **Login con Google corregido:** Ya se puede ingresar como cliente, secretario o emprendedor (pidiendo solo nombre de tienda).
- ✅ **Teléfono opcional y sin solicitud de dirección:** Formularios rápidos y sin obstáculos.
- ✅ **Identificadores ordenados:** Códigos claros como `cli001_...`, `Vent001` y `Pago001`.
- ✅ **Aplicación estable y limpia:** Cero errores de Google Sheets, código analizado (`flutter analyze` limpio) y APK disponible para todo el equipo en GitHub.
