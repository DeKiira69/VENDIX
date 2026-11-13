# 📋 Informe Técnico Detallado: Reestructuración de Autenticación, Sistema de Empleo y Resolución de Observaciones

> **Fecha de Documentación:** 12 de Noviembre de 2026  
> **Proyecto:** VENDIX — Plataforma de Gestión de Ventas en Vivo para Emprendimientos  
> **Autor de las funciones documentadas:** Trabajo integral solicitado por el usuario y desarrollado en esta sesión  
> **Estado:** Implementado, verificado con `dart analyze` (0 errores) y consolidado en el código fuente

---

## 1. 🎯 Objetivos de la Intervención

1. **Simplificación del Modelo de Autenticación:** Reducir la fricción inicial permitiendo registrarse únicamente como **Cliente** o como **Emprendedor**.
2. **Ciclo de Vida Laboral y Postulación a Empleo:** Convertir el rol de **Secretario** en una relación laboral formal donde el cliente solicita empleo a un emprendedor registrado, pudiendo trabajar con múltiples emprendimientos y alternar de rol dinámicamente.
3. **Identidad del Negocio:** Incorporar el campo obligatorio de **Nombre del Emprendimiento** en todo el ciclo de vida del administrador.
4. **Herramienta de Diagnóstico Relacional:** Construir un dashboard web (`web_relaciones.html`) que permita auditar visualmente las relaciones jerárquicas y transaccionales en Firestore.
5. **Resolución de las 5 Observaciones Críticas de Negocio:**
   - Reinicio de ventas en el Live sin persistencia visual residual.
   - Visualización inmediata de pagos en la interfaz Flutter.
   - Eliminación de pantallas rojas (excepciones de tipo) y sincronización de saldos.
   - Estadísticas comerciales con selector de fecha (calendario/mes) y botón de limpieza de vista.
   - Eliminación de la opción "Seguridad y accesos" en el menú de cuenta.

---

## 2. 🔐 Reestructuración de la Autenticación (Solo 2 Roles)

### 2.1. Eliminación del Botón Directo de Secretario en Login
En `lib/screens/auth/login_screen.dart`, se modificó el widget `_SelectorRegistroAnimado`:
- **Antes:** Se mostraban 3 botones independientes (Secretario, Cliente, Emprendedor). Los secretarios se registraban de forma aislada y quedaban en un limbo sin emprendedor asignado.
- **Ahora:** Solo existen 2 botones visibles:
  1. `Soy Cliente`: Registro directo para compradores con acceso al catálogo y Lives.
  2. `Soy Emprendedor`: Registro comercial para dueños de tiendas que administran inventarios, lives y secretarios.

```
┌─────────────────────────────────────────────────────────────┐
│                 PANTALLA DE AUTENTICACIÓN                   │
├──────────────────────────────┬──────────────────────────────┤
│          ROL CLIENTE         │       ROL EMPRENDEDOR        │
├──────────────────────────────┼──────────────────────────────┤
│ • Acceso a transmisiones     │ • Creación de catálogo       │
│ • Chatbot inteligente        │ • Aprobación de secretarios  │
│ • Consulta de saldo          │ • Métricas consolidadas      │
│ • Postulación a empleo       │ • Supervisión de cobros      │
└──────────────────────────────┴──────────────────────────────┘
```

---

## 3. 💼 Sistema de Empleo y Multiempleo para Secretarios

### 3.1. Pantalla de Solicitud de Empleo: `lib/screens/client/solicitud_empleo_screen.dart`
Se creó una pantalla dedicada accesible desde el perfil del cliente:
- **Consulta en Vivo:** Lee la colección `Administradores` en Firestore filtrando únicamente negocios activos.
- **Tarjeta de Emprendedor:** Muestra el nombre comercial del negocio, nombre del propietario, correo, teléfono y el estado actual de la postulación (`Sin postular`, `Pendiente de aprobación`, `Aprobado` o `Rechazado`).
- **Postulación en Un Toque:** Al presionar *"Postularme como Secretario"*, se genera o actualiza un documento en la colección `secretarios` con la estructura:
  ```json
  {
    "uid": "ID_DEL_USUARIO",
    "nombre": "Nombre del Cliente",
    "email": "correo@cliente.com",
    "adminId": "ID_DEL_EMPRENDEDOR",
    "nombreEmprendimiento": "Moda Luna",
    "aprobado": false,
    "estado": "pendiente",
    "fechaSolicitud": "Timestamp"
  }
  ```

### 3.2. Alternancia Dinámica de Roles (Cliente ↔ Secretario)
En `lib/screens/client/client_profile_screen.dart`:
- Se implementó un `StreamBuilder` sobre la colección `secretarios` que detecta en tiempo real si el usuario actual tiene empleos con estado `aprobado: true`.
- **Si tiene 1 empleo aprobado:** Muestra un botón destacado *"Entrar como Secretario de [Nombre Emprendimiento]"* que navega a `SecretaryShell`.
- **Si tiene múltiples empleos aprobados:** Despliega un diálogo modal (`showDialog`) que lista los diferentes emprendimientos para los cuales trabaja, permitiendo al usuario elegir en cuál de ellos desea operar en esa sesión.
- **Retorno a Modo Cliente:** En `lib/screens/secretary/more_screen.dart`, se colocó el botón *"Cambiar a modo Cliente"*, permitiendo regresar a la vista de comprador sin tener que cerrar sesión ni perder sus credenciales.

---

## 4. 🏷️ Campo "Nombre de Emprendimiento"

Se integró de extremo a extremo en el ecosistema:
1. **Modelo `AdministradorModel`:** Se agregó el atributo final `nombreEmprendimiento` con deserialización tolerante a nulos en `fromMap()` y persistencia en `toMap()`.
2. **Formulario de Registro (`register_admin_screen.dart`):** Campo de texto con validación obligatoria *"Nombre de tu Emprendimiento o Tienda"*.
3. **Flujo Google Sign-In:** Modal adaptado para solicitar el nombre comercial antes de completar el alta en Firebase.
4. **Edición de Perfil (`admin_profile_screen.dart`):** El emprendedor puede actualizar su razón social en cualquier momento mediante un batch write que replica el cambio en `Administradores/{uid}` y `usuarios/{uid}`.

---

## 5. 🌐 Panel de Diagnóstico Relacional: `web_relaciones.html`

Para facilitar las auditorías de datos, pruebas locales y depuración:
- Archivo HTML/JavaScript interactivo de página única ubicado en la raíz del proyecto.
- Se conecta mediante el SDK Web de Firebase a las colecciones:
  - `Administradores`
  - `secretarios`
  - `clientes`
  - `compras`
  - `pagos`
- **Capacidades visuales:**
  - Contador global de usuarios por rol y volumen total de dinero vendido vs. cobrado.
  - Árbol relacional: Muestra qué secretarios pertenecen a qué emprendedor, su estado de aprobación (Pendiente / Aprobado) y qué clientas han sido atendidas por cada uno.
  - Tabla de ventas del Live con cálculo automático de saldos deudores en tiempo real.

---

## 6. 🛠️ Solución Detallada a las 5 Observaciones del Usuario

### 📌 Observación 1: Reinicio de Ventas Rápidas en el Live sin Pérdida Histórica
- **Problema Detectado:** En `quick_sales_screen.dart`, la interfaz envolvía la lista de clientes dentro de un `StreamBuilder` sobre toda la colección `compras`, acumulando compras históricas en las filas del Live (`prendasHistoricas[id]`). Al presionar "Guardar venta", la clienta seguía mostrando `"5 prendas, $120.00"`, confundiendo a la secretaria sobre qué prendas correspondían a la transmisión en curso.
- **Solución Implementada:**
  1. Se eliminó el `StreamBuilder` de compras históricas del Live.
  2. Las filas de clientas ahora calculan exclusivamente `_cantidadPendiente(id)` y `_totalPendiente(id)` (la memoria viva del Live en curso).
  3. Al confirmar *"Registrar venta"* o *"Guardar todo"*, las órdenes se graban en la colección `compras` de Firestore y se ejecuta `_pedidosPendientes.clear()`.
  4. La pantalla del Live se reinicia instantáneamente a **0 prendas y \$0.00**, mientras que en **Administrar Clientes** (`clients_screen.dart`) el histórico permanece intacto para la gestión de cobros.

### 📌 Observación 2: Registro de Pagos Reflejado Inmediatamente en Flutter
- **Problema Detectado:** Al registrar un pago desde la interfaz, los cálculos de deuda en algunos componentes no reflejaban el abono hasta reiniciar la app.
- **Solución Implementada:**
  1. En `clients_screen.dart` y `payments_screen.dart`, el registro de abonos no solo agrega el documento en `pagos`, sino que actualiza inmediatamente el campo `saldo` en el documento correspondiente de la colección `clientes` mediante `SetOptions(merge: true)`.
  2. Se aseguró que los `StreamBuilder` escuchen la colección reactiva de Firestore para que el widget recalcule el estado (`AL DÍA` o `DEBE $xx.xx`) sin recargar la pantalla.

### 📌 Observación 3: Solución de Pantalla Roja en Resumen de Clienta y Pagos
- **Problema Detectado:** Al abrir el "Resumen de clienta" o registrar un pago, aparecía la temida **pantalla roja de error de Flutter**.
  - **Causa Raíz 1 (Casting numérico):** Firestore almacenaba en ciertos registros valores de tipo `String` (ej. `"25.00"`). El código ejecutaba `(compra['total'] as dynamic).toDouble()`, disparando:
    `NoSuchMethodError: Class 'String' has no instance method 'toDouble'`
  - **Causa Raíz 2 (Índice Compuesto Faltante):** En `payments_screen.dart`, la consulta `.where('clienteId', ...).orderBy('fecha', descending: true)` fallaba en Firestore si no existía el índice compuesto configurado en la consola.
- **Solución Implementada:**
  1. Se crearon las funciones utilitarias seguras `_toDouble(dynamic v)` y `_toInt(dynamic v)` que parsean strings, números o nulos sin lanzar jamás excepciones.
  2. Se aplicó `_toDouble` en todos los cálculos de `clients_screen.dart` y `payments_screen.dart`.
  3. Se removió el `.orderBy` de la consulta Firestore en `payments_screen.dart` y se implementó el ordenamiento cronológico directamente en la memoria de Dart (`List.sort()`), eliminando el requisito de índices compuestos.

### 📌 Observación 4: Estadísticas Comerciales Avanzadas y Limpieza de Pantalla
- **Problema Detectado:** La pantalla `statistics_screen.dart` era un `StatelessWidget` estático sin filtros temporales ni métricas accionables.
- **Solución Implementada:**
  1. Se convirtió la pantalla a `StatefulWidget`.
  2. **Selector de Fecha Tipo Calendario:**
     - Botón `Todo`: Muestra el consolidado histórico acumulado.
     - Botón `Por día`: Abre un `DatePicker` oficial y filtra únicamente ventas y pagos del día seleccionado.
     - Botón `Por mes`: Permite auditar el rendimiento comercial de un mes y año específicos.
  3. **Botón de Limpiar Vista (Ícono de Escoba/Limpieza en AppBar):**
     - Permite despejar la pantalla para comenzar una nueva visualización limpia sin borrar **ni un solo dato** de Firestore.
     - Incluye botón *"Restaurar"* y aviso de seguridad para tranquilidad de la secretaria.
  4. **Nuevos Indicadores para Futuras APIs y Dashboards:**
     - Total de transacciones registradas.
     - Ratio de clientas activas frente al total de registradas.
     - Detección de **Hora Pico de Ventas** (franja horaria con mayor actividad comercial durante el Live).

### 📌 Observación 5: Eliminación de "Seguridad y Accesos" en Ajustes de Cuenta
- **Problema Detectado:** En la vista de ajustes de cuenta de `admin_more_screen.dart`, existía la opción *"Seguridad y accesos"* que no tenía funcionalidad implementada y confundía la navegación.
- **Solución Implementada:** Se removió el `ListTile` correspondiente y su separador `Divider`, dejando únicamente *"Tema y apariencia"* y el botón seguro de *"Cerrar sesión"*.

---

## 7. 🔤 Corrección de Codificación UTF-8 y Mojibake

Durante la revisión exhaustiva de archivos:
- Se eliminó el caracter **BOM (Byte Order Mark)** presente en `quick_sales_screen.dart` (`\xef\xbb\xbf`).
- Se corrigió la doble codificación del punto medio `·` (`\xc3\x82\xc2\xb7` → `\xc2\xb7`).
- Se reparó el emoji de confirmación de venta triple-codificado (`âœ…` → `✅`).
- Se normalizaron tildes en etiquetas de navegación (`Perfil / Más`, `REGISTRO RÁPIDO`, `teléfono`).
