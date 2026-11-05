# Arquitectura del Sistema VENDIX (Formato Diapositiva Canva)

> [!NOTE]
> Esta estructura replica **exactamente el diseño, bloques y estilo de la diapositiva de muestra (SeñAPP)**, adaptada 100% a la realidad de carpetas, archivos y lógica de **VENDIX**.

---

## 🖼️ Estructura Visual de la Diapositiva

### Encabezado Superior
* **Izquierda (Nombre de la App):** `Vendix`
* **Centro (Título Principal):** **Arquitectura del sistema**
* **Derecha (Asignatura):** `ESPOCH · Interoperabilidad de Plataformas`
* **Subtítulo descriptivo:**
  > *"El código se organiza modularmente por roles y separa responsabilidades en capas bajo el patrón MVC, comunicándose de forma reactiva con Firebase."*

---

### 📦 Bloque Izquierdo: ORGANIZACIÓN POR FUNCIONES
*(Cajitas estilo botones o píldoras con los módulos reales de VENDIX)*

* `auth - acceso y roles`
* `admin - panel y secretarios`
* `sales - ventas rápidas en vivo`
* `clothing - prendas y precios`
* `clients - gestión de clientas`
* `client_portal - portal y saldos`

**Texto inferior:**
* **`theme`** · colores, tipografías y estilos visuales compartidos
* **`main / firebase_options`** · arranque, bloqueo vertical y configuración

---

### 🧱 Bloque Derecho: CAPAS DENTRO DEL SISTEMA (MVC)
*(3 tarjetas rectangulares alineadas horizontalmente)*

#### 01 Vista (Screens)
* **Contenido:** Pantallas, widgets interactivos y modales; recibe las acciones del usuario (`login_screen`, `admin_home_screen`, `clients_screen`).

#### 02 Modelo (Domain / Data)
* **Contenido:** Clases fuertemente tipadas: `AdministradorModel`, `PrendaModel`, `ClienteDemo`; serialización `fromMap` y `toMap`.

#### 03 Controlador (Services)
* **Contenido:** Lógica de negocio y cálculo (`PrendaService`, `ClientService`); consultas y streams en tiempo real a Firebase.

---

### 📁 Bloque Central: ESTRUCTURA REAL DE CARPETAS (`lib/`)
*(Dos capturas o cajitas oscuras con la jerarquía real del proyecto)*

```text
📁 lib/
  ├── 📁 data/            (servicios y datos locales)
  ├── 📁 models/          (modelos de datos Dart)
  ├── 📁 screens/         (pantallas organizadas por rol)
  ├── 📁 services/        (servicios de clientes y compras)
  ├── 📁 theme/           (tema global y paleta de color)
  ├── 📄 firebase_options.dart
  └── 📄 main.dart
```

**Desglose específico de `screens/`:**
```text
📁 screens/
  ├── 📁 auth/        -> Login y registros (Admin / Cliente)
  ├── 📁 admin/       -> Dashboard, KPIs y secretarios
  ├── 📁 secretary/   -> Ventas en vivo, catálogo y clientas
  └── 📁 client/      -> Consulta de saldo y compras
```

---

### ➡️ Bloque Inferior: FLUJO DE AUTENTICACIÓN Y ROLES
*(Secuencia de cajitas horizontales conectadas con flechas `>`)*

`[ LoginScreen ]`  ➔  `[ _iniciarSesion() ]`  ➔  `[ FirebaseAuth ]`  ➔  `[ Verificación Firestore (Administradores / usuarios / secretarios) ]`  ➔  `⭐ [ Redirección a AdminHomeScreen / SecretaryShell / ClientShell ]`

---

## 📋 Cuadro Resumen Listo para Pegar en Canva

| Elemento en Canva | Texto a Colocar para VENDIX |
| :--- | :--- |
| **Título** | **Arquitectura del sistema** |
| **Subtítulo** | El código se organiza por módulos de rol y separa responsabilidades en capas MVC; conexión reactiva con Firebase. |
| **Funciones (Tags)** | `auth - acceso`, `admin - gestión`, `sales - live`, `clothing - catálogo`, `clients - clientas`, `client - portal` |
| **Capa 01** | **01 Vista (Presentación):** Pantallas, modales y formularios reactivos (`StreamBuilder`). |
| **Capa 02** | **02 Modelo (Datos):** Modelos `PrendaModel`, `AdministradorModel`, serializadores JSON/Firestore. |
| **Capa 03** | **03 Controlador (Servicios):** `PrendaService`, `ClientService` y lógica de cálculo de saldos y stock. |
| **Flujo inferior** | `LoginScreen` ➔ `RoleController` ➔ `Firebase Auth` ➔ `Firestore Rules` ➔ **Enrutamiento por Rol** |
